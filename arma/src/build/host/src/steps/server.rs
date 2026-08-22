use std::{
    fs,
    process::{Command, Stdio},
    sync::Arc,
    thread,
    time::Duration,
};

use crate::{
    context::{BuildContext, BuildOS, InstanceContext},
    error::{BuildError, BuildResult},
    spinner::MultiSpinner,
    target::Target,
};

/// How often the build tells the target it is still alive. The staleness threshold it is measured against
/// belongs to the watchdog, and so lives with the target that spawns one.
const HEARTBEAT_INTERVAL_SECS: u64 = 5;

/// Where `record_game_address` leaves the address, relative to the local `target/` directory. Read by the
/// service's A2S specs; see `spec/esm/steam/server_query_spec.rb`.
const GAME_ADDRESS_FILE: &str = "dev-server-address";

/// Name prefix shared by every server's container, and so the way to spot one this build should be managing.
///
/// Matched unanchored on purpose. An interrupted `docker compose up` leaves the container it was replacing
/// renamed to `<id prefix>_<name>`, which still contains this but no longer starts with it.
const CONTAINER_PREFIX: &str = "ESM_ARMA_";

/// Report in on a loop until the build exits.
///
/// Runs on a detached daemon thread, so it stops the instant the build process goes away and the target-side
/// watchdog takes over from there. Errors are dropped on purpose: a missed beat is what the watchdog is
/// tolerant of, and a build that printed a warning every time the network hiccuped would train people to
/// ignore it.
fn spawn_heartbeat(target: Arc<dyn Target>) {
    thread::spawn(move || loop {
        let _ = target.heartbeat();
        thread::sleep(Duration::from_secs(HEARTBEAT_INTERVAL_SECS));
    });
}

/// Ensure this server's container is running.
///
/// The bind-mount sources under `.docker-volumes/instances/` are left for Docker to create. They end up owned
/// by root, same as the shared volumes, which is what the container wants: everything inside it runs as root,
/// and the build only ever reaches in through `docker cp` and `docker exec`.
pub fn ensure_container(ictx: &InstanceContext) -> BuildResult {
    // A remote host is not something this tool brings up. It is already running, or the build fails at the
    // first command with an ssh error that says so far better than a container check could.
    if matches!(ictx.args().build_os(), BuildOS::Windows) {
        return Ok(());
    }

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
    if matches!(ctx.args.build_os(), BuildOS::Windows) {
        return Ok(());
    }

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

/// Install or update the Arma 3 server through SteamCMD, if absent or `--update` was passed.
///
/// The install is shared by every server on a target, so this runs once per build rather than once per server.
///
/// Draws its own progress instead of going through `run_instance_step`, because a validating download of a 5GB
/// install is minutes long: a spinner with nothing under it is indistinguishable from a hang, which is exactly
/// what it looked like before.
pub fn update_arma(ictx: &InstanceContext) -> BuildResult {
    let mut spinner = MultiSpinner::start("Updating Arma");
    let sub_lines = spinner.sub_lines();

    let result = ictx.target.install_arma(
        &ictx.config().server.steam_user,
        &ictx.config().server.steam_password,
        &mut |line| {
            // SteamCMD is chatty about things nobody is waiting on, and its own progress lines are the point.
            if line.trim().is_empty() {
                return;
            }

            sub_lines.print(line);
        },
    );

    match result {
        Ok(()) => {
            spinner.done();
            Ok(())
        }
        Err(e) => {
            spinner.sub_fail("SteamCMD", true);
            Err(e)
        }
    }
}

/// Stop any running Arma 3 server on the target.
pub fn kill_arma(ictx: &InstanceContext) -> BuildResult {
    ictx.target.kill_arma()
}

/// Clean the logs, RPTs and crash dumps left by the previous run.
pub fn clean_logs(ictx: &InstanceContext) -> BuildResult {
    ictx.target.clean_logs()
}

/// Start the Arma 3 server, guarded by a watchdog so it dies with this build process.
pub fn start_server(ictx: &InstanceContext) -> BuildResult {
    ictx.target.start_arma(ictx.args().build_arch())?;
    record_game_address(ictx)?;
    spawn_heartbeat(ictx.target.clone());
    Ok(())
}

/// Leave the started server's address where the spec suite can find it.
///
/// Steam queries go over UDP straight at the game port, so unlike everything else the specs do they cannot ride
/// the connection the extension already holds open: they have to name a host. Which host that is depends on what
/// this build was aimed at, and this run is the last thing that knew. Writing it down turns a target switch into
/// something the specs pick up on their own, rather than a value kept in step by hand in two places.
///
/// Only the default instance writes it, because only the default instance is reachable: the spec harness talks
/// to the first server in config.yml and says so when it cannot. A `--server-id` run of any other server leaves
/// this alone rather than pointing the specs at a server they will not connect to.
fn record_game_address(ictx: &InstanceContext) -> BuildResult {
    if !ictx.is_default_instance() {
        return Ok(());
    }

    let path = ictx.build.local_build_path.join(GAME_ADDRESS_FILE);
    fs::create_dir_all(&ictx.build.local_build_path)?;
    fs::write(path, ictx.game_address())?;

    Ok(())
}

pub fn needs_arma_update(ictx: &InstanceContext) -> bool {
    !ictx.target.arma_installed(ictx.args().build_arch()) || ictx.args().update_arma()
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
