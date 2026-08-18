use std::{
    process::{Command, Stdio},
    thread,
    time::Duration,
};

use crate::{
    context::{BuildArch, BuildContext, InstanceContext},
    error::{BuildError, BuildResult},
    ARMA_PATH, LINUX_EXES,
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

/// Name prefix shared by every server's container, and so the way to spot one this build should be managing.
///
/// Matched unanchored on purpose. An interrupted `docker compose up` leaves the container it was replacing
/// renamed to `<id prefix>_<name>`, which still contains this but no longer starts with it.
const CONTAINER_PREFIX: &str = "ESM_ARMA_";

/// Touch the heartbeat file in the container on a loop until the process exits.
/// Runs on a detached daemon thread, so it stops the instant the host process
/// goes away and the container-side watchdog takes over from there.
fn spawn_heartbeat(container: String) {
    thread::spawn(move || loop {
        let _ = Command::new("docker")
            .args(["exec", &container, "touch", HEARTBEAT_FILE])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status();
        thread::sleep(Duration::from_secs(HEARTBEAT_INTERVAL_SECS));
    });
}

/// Ensure this server's container is running.
///
/// The bind-mount sources under `.docker-volumes/instances/` are left for Docker to create. They end up owned
/// by root, same as the shared volumes, which is what the container wants: everything inside it runs as root,
/// and the build only ever reaches in through `docker cp` and `docker exec`.
pub fn ensure_container(ictx: &InstanceContext) -> BuildResult {
    let container = ictx.container();

    // Run this even when the container is already up: compose recreates on config drift, which is what picks
    // up a changed mount or port. Skipping it while running would silently keep an outdated container alive.
    // One compose project per server so each gets its own container, ports, and volume set out of the same
    // compose file. The env vars are what the file interpolates.
    //
    // Output is captured rather than inherited: compose draws a live progress display, and letting it write
    // to the terminal means it and the spinner redraw over each other.
    let output = Command::new("docker")
        .args([
            "compose",
            "--progress",
            "quiet",
            "-p",
            &ictx.instance.compose_project(),
            "up",
            "-d",
        ])
        .current_dir(&ictx.build.git_path)
        .env("ESM_SERVER_ID", &ictx.instance.server_id)
        .env("ESM_CONTAINER", &container)
        .env("ESM_PORT_BASE", ictx.instance.port.to_string())
        .env("ESM_PORT_LAST", ictx.instance.last_port().to_string())
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !output.status.success() {
        return Err(BuildError::Docker(format!(
            "docker compose up failed for {container}: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        )));
    }

    const TIMEOUT_SECS: u32 = 30;
    for _ in 0..TIMEOUT_SECS {
        if is_container_running(&container) {
            return Ok(());
        }
        thread::sleep(Duration::from_secs(1));
    }

    Err(BuildError::Docker(format!(
        "Timed out waiting for the Arma container {container} to start"
    )))
}

/// Remove every ESM container that no configured server answers to.
///
/// Two ways one gets there. Dropping an `instances` entry leaves its container behind still holding its published
/// ports, so the next server to claim that range collides with a server nobody remembers configuring. An
/// interrupted `docker compose up` leaves a container Docker renamed out of the way mid-recreate, which no step
/// can reach afterwards because every one of them addresses containers by their configured name; the symptom is
/// the next build timing out waiting for a container that already exists under a name nobody is looking for.
///
/// Either way the name is the whole story: a container no configured server answers to cannot be managed, so it
/// goes. Only containers are removed. The host-side volumes stay, so a server picks its state back up on the next
/// start, which is what makes clearing one out cheap enough to do unprompted.
pub fn remove_orphaned_containers(ctx: &mut BuildContext) -> BuildResult {
    let configured: Vec<String> = ctx
        .config
        .instances
        .iter()
        .map(|instance| instance.container())
        .collect();

    let output = Command::new("docker")
        .args([
            "ps",
            "-a",
            "--filter",
            &format!("name={CONTAINER_PREFIX}"),
            "--format",
            "{{.Names}}",
        ])
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    let names = String::from_utf8_lossy(&output.stdout).into_owned();
    let orphans: Vec<&str> = names
        .lines()
        .map(str::trim)
        .filter(|name| !name.is_empty() && !configured.iter().any(|known| known == name))
        .collect();

    if orphans.is_empty() {
        return Ok(());
    }

    Command::new("docker")
        .args(["rm", "-f"])
        .args(&orphans)
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    Ok(())
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
///
/// The install is shared by every server, so this runs once per build rather than once per server.
pub fn update_arma(ictx: &InstanceContext) -> BuildResult {
    ictx.target.run(
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
        user = ictx.config().server.steam_user,
        pass = ictx.config().server.steam_password,
    );

    ictx.target.run(&script)?;
    Ok(())
}

/// Stop any running Arma 3 server processes in the container.
pub fn kill_arma(ictx: &InstanceContext) -> BuildResult {
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

    ictx.target.run(&script).ok(); // ignore errors — no process is fine
    Ok(())
}

/// Clean old log and RPT files from the container.
pub fn clean_logs(ictx: &InstanceContext) -> BuildResult {
    let server = ictx.server_path();
    let script = format!(
        "rm -f '{server}/server_profile/'*.log \
               '{server}/server_profile/'*.rpt \
               '{server}/server_profile/'*.bidmp \
               '{server}/server_profile/'*.mdmp \
               '{server}/server_profile/'*.txt; \
         rm -rf '{server}/@exileserver/logs'",
        server = server.display()
    );
    ictx.target.run(&script).ok(); // best-effort
    Ok(())
}

/// Start the Arma 3 server inside the container, guarded by a heartbeat
/// watchdog so it dies with the host process (see the module header).
pub fn start_server(ictx: &InstanceContext) -> BuildResult {
    let server = ictx.server_path();
    let exe = match ictx.args().build_arch() {
        BuildArch::X32 => "arma3server",
        BuildArch::X64 => "arma3server_x64",
    };
    let args = ictx.target.server_args().to_string();

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

    ictx.target.run(&script)?;
    spawn_heartbeat(ictx.container());
    Ok(())
}

pub fn needs_arma_update(ictx: &InstanceContext) -> bool {
    let check = format!(
        "test -f '{ARMA_PATH}/arma3server' && echo 1 || echo 0"
    );

    let result = ictx.target.run(&check).unwrap_or_default();
    result.trim() != "1" || ictx.args().update_arma()
}

fn is_container_running(container: &str) -> bool {
    let Ok(output) = Command::new("docker")
        .args(["container", "inspect", "-f", "{{.State.Status}}", container])
        .output()
    else {
        return false;
    };

    let status = String::from_utf8_lossy(&output.stdout);
    status.trim() == "running"
}
