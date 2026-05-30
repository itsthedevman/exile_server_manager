use std::{
    process::{Command, Stdio},
    thread,
    time::Duration,
};

use crate::{
    context::{BuildArch, BuildContext},
    error::{BuildError, BuildResult},
    ARMA_CONTAINER, ARMA_PATH, LINUX_EXES,
};

// Heartbeat reaper. The host process touches HEARTBEAT_FILE every few seconds
// (spawn_heartbeat); a watchdog inside the container kills the server when
// those touches go stale. This couples the server's life to the host process
// no matter how the host dies — Ctrl-C, a closed terminal, even an uncatchable
// SIGKILL — so arma3server can't be orphaned inside the persistent container.
const HEARTBEAT_FILE: &str = "/tmp/esm_heartbeat";
const SERVER_PID_FILE: &str = "/tmp/esm_server.pid";
const WATCHDOG_PID_FILE: &str = "/tmp/esm_watchdog.pid";
const HEARTBEAT_INTERVAL_SECS: u64 = 5;
const HEARTBEAT_STALE_SECS: u64 = 15;
const HEARTBEAT_POLL_SECS: u64 = 3;

/// Touch the heartbeat file in the container on a loop until the process exits.
/// Runs on a detached daemon thread, so it stops the instant the host process
/// goes away and the container-side watchdog takes over from there.
fn spawn_heartbeat() {
    thread::spawn(|| loop {
        let _ = Command::new("docker")
            .args(["exec", ARMA_CONTAINER, "touch", HEARTBEAT_FILE])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
        thread::sleep(Duration::from_secs(HEARTBEAT_INTERVAL_SECS));
    });
}

/// Ensure the Docker Compose stack is running.
pub fn ensure_container(_ctx: &mut BuildContext) -> BuildResult {
    if !is_container_running() {
        Command::new("docker")
            .args(["compose", "up", "-d"])
            .status()
            .map_err(|e| BuildError::Docker(e.to_string()))?;
    }

    const TIMEOUT_SECS: u32 = 30;
    for _ in 0..TIMEOUT_SECS {
        if is_container_running() {
            return Ok(());
        }
        thread::sleep(Duration::from_secs(1));
    }

    Err(BuildError::Docker(
        "Timed out waiting for the Arma container to start".into(),
    ))
}

/// Check that the Exile mod files are present locally (required on the server).
pub fn check_for_exile_files(ctx: &mut BuildContext) -> BuildResult {
    let exile_path = ctx
        .git_path
        .join("tools")
        .join("server")
        .join("@exile")
        .join("addons");

    if exile_path.join("exile_client.pbo").exists() {
        return Ok(());
    }

    Err(BuildError::General(format!(
        "Missing @exile addon files in {}.\n\
         Download the Exile Mod client files and copy the contents of its \
         addons directory to that path.",
        exile_path.display()
    )))
}

/// Update the Arma 3 server via SteamCMD (only if files are absent or --update).
pub fn update_arma(ctx: &mut BuildContext) -> BuildResult {
    ctx.target.run(
        "if [ ! -f /steamcmd/steamcmd.sh ]; then \
           mkdir -p /steamcmd && \
           wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' \
             | tar zxf - -C /steamcmd; \
         fi",
    )?;

    let script = format!(
        "cd /steamcmd; \
         ./steamcmd.sh +force_install_dir {ARMA_PATH} \
         +login {user} {pass} \
         +app_update 233780 validate \
         +quit",
        user = ctx.config.server.steam_user,
        pass = ctx.config.server.steam_password,
    );

    ctx.target.run(&script)?;
    Ok(())
}

/// Stop any running Arma 3 server processes in the container.
pub fn kill_arma(ctx: &mut BuildContext) -> BuildResult {
    let exes = LINUX_EXES
        .iter()
        .map(|e| format!("'{}'", e.rsplit('/').next().unwrap_or(e)))
        .collect::<Vec<_>>()
        .join("|");

    let script = format!(
        "for pid in $(ps -ef | awk '/({exes})/ {{print $2}}'); \
         do kill -9 \"$pid\" 2>/dev/null || true; done; \
         kill -9 $(cat {wpid} 2>/dev/null) 2>/dev/null || true; \
         rm -f {hb} {spid} {wpid}",
        wpid = WATCHDOG_PID_FILE,
        hb = HEARTBEAT_FILE,
        spid = SERVER_PID_FILE,
    );

    ctx.target.run(&script).ok(); // ignore errors — no process is fine
    Ok(())
}

/// Clean old log and RPT files from the container.
pub fn clean_logs(ctx: &mut BuildContext) -> BuildResult {
    let server = ctx.target.server_path();
    let script = format!(
        "rm -f '{server}/server_profile/'*.log \
               '{server}/server_profile/'*.rpt \
               '{server}/server_profile/'*.bidmp \
               '{server}/server_profile/'*.mdmp \
               '{server}/server_profile/'*.txt; \
         rm -rf '{server}/@exileserver/logs'",
        server = server.display()
    );
    ctx.target.run(&script).ok(); // best-effort
    Ok(())
}

/// Start the Arma 3 server inside the container, guarded by a heartbeat
/// watchdog so it dies with the host process (see the module header).
pub fn start_server(ctx: &mut BuildContext) -> BuildResult {
    let server = ctx.target.server_path();
    let exe = match ctx.args.build_arch() {
        BuildArch::X32 => "arma3server",
        BuildArch::X64 => "arma3server_x64",
    };
    let args = ctx.target.server_args().to_string();

    // The watchdog reaps the server by its recorded PID once the heartbeat
    // stops being refreshed, then cleans up its own bookkeeping. It is wrapped
    // in single quotes so its `$(...)` expand at watchdog runtime, not here.
    let script = format!(
        "mkdir -p '{server}/server_profile'; \
         touch {hb}; \
         nohup '{server}/{exe}' {args} \
           >'{server}/server_profile/server.log' 2>&1 </dev/null & \
         echo $! > {spid}; \
         nohup bash -c '\
           spid=$(cat {spid}); \
           while sleep {poll}; do \
             beat=$(stat -c %Y {hb} 2>/dev/null || echo 0); \
             if [ $(( $(date +%s) - beat )) -ge {stale} ]; then \
               kill -9 $spid 2>/dev/null; \
               rm -f {hb} {spid} {wpid}; \
               exit 0; \
             fi; \
           done' >/dev/null 2>&1 </dev/null & \
         echo $! > {wpid}",
        server = server.display(),
        hb = HEARTBEAT_FILE,
        spid = SERVER_PID_FILE,
        wpid = WATCHDOG_PID_FILE,
        poll = HEARTBEAT_POLL_SECS,
        stale = HEARTBEAT_STALE_SECS,
    );

    ctx.target.run(&script)?;
    spawn_heartbeat();
    Ok(())
}

pub fn needs_arma_update(ctx: &BuildContext) -> bool {
    let check = format!(
        "test -f '{ARMA_PATH}/arma3server' && echo 1 || echo 0"
    );

    let result = ctx.target.run(&check).unwrap_or_default();
    result.trim() != "1" || ctx.args.update_arma()
}

fn is_container_running() -> bool {
    let Ok(output) = Command::new("docker")
        .args(["container", "inspect", "-f", "{{.State.Status}}", ARMA_CONTAINER])
        .output()
    else {
        return false;
    };

    let status = String::from_utf8_lossy(&output.stdout);
    status.trim() == "running"
}
