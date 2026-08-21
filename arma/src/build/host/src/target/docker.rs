use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command as Cmd, Stdio};

use crate::{
    config::{Config, Instance},
    context::BuildArch,
    error::BuildError,
};

// Heartbeat reaper. The build process refreshes HEARTBEAT_FILE every few seconds; a watchdog inside the
// container kills the server once those touches go stale. This couples the server's life to the build no matter
// how the build died -- Ctrl-C, a closed terminal, even an uncatchable SIGKILL -- so arma3server cannot be
// orphaned inside the persistent container.
const HEARTBEAT_FILE: &str = "/tmp/esm_heartbeat";
const SERVER_PID_FILE: &str = "/tmp/esm_server.pid";
const WATCHDOG_PID_FILE: &str = "/tmp/esm_watchdog.pid";
const HEARTBEAT_STALE_SECS: u64 = 15;
const HEARTBEAT_POLL_SECS: u64 = 3;

/// Write a file inside a container, piping the contents over stdin.
///
/// Going through stdin rather than the command line keeps shell quoting out of the picture, which matters for
/// server keys and config values that can hold anything.
pub fn write_file(
    container: &str,
    path: &Path,
    contents: &[u8],
) -> Result<(), BuildError> {
    let cmd = format!("cat > '{}'", path.display());

    let mut child = Cmd::new("docker")
        .args(["exec", "-i", container, "/bin/bash", "-c", &cmd])
        .stdin(Stdio::piped())
        .spawn()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(contents)
            .map_err(|e| BuildError::Docker(e.to_string()))?;
    }

    let status = child
        .wait()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !status.success() {
        return Err(BuildError::Docker(format!(
            "Failed to write {} in {container} (exit {:?})",
            path.display(),
            status.code()
        )));
    }

    Ok(())
}

pub struct DockerTarget {
    #[allow(dead_code)]
    build_path: PathBuf,
    server_path: PathBuf,
    server_args: String,
    container: String,
}

impl DockerTarget {
    pub fn new(config: &Config, instance: &Instance) -> Self {
        // The game port is the one launch argument that has to differ per server; config.yml carries the rest
        // verbatim because every other path resolves the same way inside every container.
        let server_args = config
            .server
            .server_args
            .iter()
            .map(|arg| format!("-{arg}"))
            .chain(std::iter::once(format!("-port={}", instance.port)))
            .collect::<Vec<_>>()
            .join(" ");

        DockerTarget {
            build_path: PathBuf::from("/tmp/esm"),
            server_path: PathBuf::from(crate::ARMA_PATH),
            server_args,
            container: instance.container(),
        }
    }

    /// Run a command directly on the host (not inside the container).
    #[allow(dead_code)]
    pub fn run_local(cmd: &str) -> Result<String, BuildError> {
        let output = Cmd::new("bash")
            .args(["-c", cmd])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            return Err(BuildError::Docker(format!(
                "Command failed (exit {}):\n{}\n{}",
                output.status.code().unwrap_or(-1),
                stdout.trim(),
                stderr.trim()
            )));
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }
}

impl super::Target for DockerTarget {
    fn run(&self, cmd: &str) -> Result<String, BuildError> {
        let output = Cmd::new("docker")
            .args([
                "exec",
                &self.container,
                "/bin/bash",
                "-c",
                cmd,
            ])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            return Err(BuildError::Docker(format!(
                "docker exec failed (exit {}):\n{}\n{}",
                output.status.code().unwrap_or(-1),
                stdout.trim(),
                stderr.trim()
            )));
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    fn upload(&self, local: &Path, dest: &Path) -> Result<(), BuildError> {
        // The trailing `/.` copies the contents rather than the directory itself, which is what a bind-mounted
        // destination needs: the mount point already exists and cannot be replaced from inside the container.
        let src_str = format!("{}/.", local.display());
        let dest_str = format!("{}:{}", self.container, dest.display());

        let output = Cmd::new("docker")
            .args(["cp", &src_str, &dest_str])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        if !output.status.success() {
            let msg = String::from_utf8_lossy(&output.stderr);
            return Err(BuildError::Docker(format!(
                "docker cp upload failed: {}",
                msg.trim()
            )));
        }

        Ok(())
    }

    fn download(&self, remote: &Path, local: &Path) -> Result<(), BuildError> {
        let src_str = format!("{}:{}", self.container, remote.display());

        let output = Cmd::new("docker")
            .args(["cp", &src_str, &local.display().to_string()])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        if !output.status.success() {
            let msg = String::from_utf8_lossy(&output.stderr);
            return Err(BuildError::Docker(format!(
                "docker cp download failed: {}",
                msg.trim()
            )));
        }

        Ok(())
    }

    fn write_file(&self, path: &Path, contents: &[u8]) -> Result<(), BuildError> {
        write_file(&self.container, path, contents)
    }

    fn clear_directory(&self, path: &Path) -> Result<(), BuildError> {
        self.run(&format!(
            "mkdir -p '{dir}' && find '{dir}' -mindepth 1 -delete",
            dir = path.display()
        ))?;

        Ok(())
    }

    fn exists(&self, path: &Path) -> Result<bool, BuildError> {
        let output = Cmd::new("docker")
            .args([
                "exec",
                "-t",
                &self.container,
                "/bin/bash",
                "-c",
                &format!("test -e '{}' && echo 1 || echo 0", path.display()),
            ])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        let result = String::from_utf8_lossy(&output.stdout).trim().to_string();
        Ok(result == "1")
    }

    fn install_arma(&self, steam_user: &str, steam_password: &str) -> Result<(), BuildError> {
        // The container ships without SteamCMD, so the first run fetches it. Windows installs it by hand
        // instead, which is the one place the two targets genuinely differ rather than just spelling things
        // differently.
        self.run(
            "if [ ! -f /steamcmd/steamcmd.sh ]; then \
               mkdir -p /steamcmd && \
               wget -qO- 'https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz' \
                 | tar zxf - -C /steamcmd; \
             fi",
        )?;

        self.run(&format!(
            "cd /steamcmd; \
             ./steamcmd.sh +force_install_dir {server} \
             +login {steam_user} {steam_password} \
             +app_update 233780 validate \
             +quit",
            server = self.server_path.display()
        ))?;

        Ok(())
    }

    fn arma_installed(&self, arch: BuildArch) -> bool {
        let exe = self.server_path.join(arma_executable(arch));
        self.exists(&exe).unwrap_or(false)
    }

    fn kill_arma(&self) -> Result<(), BuildError> {
        let names = crate::LINUX_EXES
            .iter()
            .map(|exe| format!("'{}'", exe.rsplit('/').next().unwrap_or(exe)))
            .collect::<Vec<_>>()
            .join("|");

        self.run(&format!(
            "for pid in $(ps -ef | awk '/({names})/ {{print $2}}'); \
             do kill -9 \"$pid\" 2>/dev/null || true; done; \
             kill -9 $(cat {wpid} 2>/dev/null) 2>/dev/null || true; \
             rm -f {hb} {spid} {wpid}",
            wpid = WATCHDOG_PID_FILE,
            hb = HEARTBEAT_FILE,
            spid = SERVER_PID_FILE,
        ))
        .ok(); // no process to kill is the expected case, not a failure

        Ok(())
    }

    fn clean_logs(&self) -> Result<(), BuildError> {
        self.run(&format!(
            "rm -f '{server}/server_profile/'*.log \
                   '{server}/server_profile/'*.rpt \
                   '{server}/server_profile/'*.bidmp \
                   '{server}/server_profile/'*.mdmp \
                   '{server}/server_profile/'*.txt; \
             rm -rf '{server}/@exileserver/logs'",
            server = self.server_path.display()
        ))
        .ok(); // best effort: a first run has nothing to clean

        Ok(())
    }

    fn start_arma(&self, arch: BuildArch) -> Result<(), BuildError> {
        // The watchdog reaps the server by its recorded PID once the heartbeat stops being refreshed, then
        // clears its own bookkeeping. Single-quoted so its `$(...)` expand when the watchdog runs, not here.
        self.run(&format!(
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
            server = self.server_path.display(),
            exe = arma_executable(arch),
            args = self.server_args,
            hb = HEARTBEAT_FILE,
            spid = SERVER_PID_FILE,
            wpid = WATCHDOG_PID_FILE,
            poll = HEARTBEAT_POLL_SECS,
            stale = HEARTBEAT_STALE_SECS,
        ))?;

        Ok(())
    }

    fn heartbeat(&self) -> Result<(), BuildError> {
        Cmd::new("docker")
            .args(["exec", &self.container, "touch", HEARTBEAT_FILE])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        Ok(())
    }

    fn build_path(&self) -> &Path {
        &self.build_path
    }

    fn server_path(&self) -> &Path {
        &self.server_path
    }

    fn server_args(&self) -> &str {
        &self.server_args
    }
}

fn arma_executable(arch: BuildArch) -> &'static str {
    match arch {
        BuildArch::X32 => "arma3server",
        BuildArch::X64 => "arma3server_x64",
    }
}

#[cfg(test)]
mod tests {
    use crate::config::parse;
    use crate::context::BuildArch;
    use crate::target::Target;

    /// Smoke test for the container target, mirroring the Windows one in `remote.rs`.
    ///
    /// Ignored by default: it needs the first configured server's container to be up. Run it after changing
    /// anything here, since these operations are only otherwise exercised by a full `--start-server` run.
    ///
    ///   cargo test -p host -- --ignored --nocapture
    #[test]
    #[ignore = "needs the first configured server's container to be running"]
    fn container_target_handles_files_and_an_idle_server() {
        let config_path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../config.yml");
        let config = parse(std::path::Path::new(config_path)).expect("config.yml");
        let instance = config.instances[0].clone();
        let target = super::DockerTarget::new(&config, &instance);

        assert_eq!(target.run("echo hello").expect("run"), "hello");

        let scratch = std::path::Path::new("/tmp/esm-target-test");
        target.clear_directory(scratch).expect("clear");

        let awkward = "quote \" backslash \\ dollar $ semi ; newline\n";
        let probe = scratch.join("probe.txt");
        target.write_file(&probe, awkward.as_bytes()).expect("write_file");
        assert!(target.exists(&probe).expect("exists"));

        let read_back = target.run(&format!("cat '{}'", probe.display())).expect("read back");
        assert_eq!(read_back.trim_end(), awkward.trim_end());

        // The directory has to survive being emptied: it is a bind mount in the real deploy.
        target.clear_directory(scratch).expect("clear again");
        assert!(target.exists(scratch).expect("root survives"));
        assert!(!target.exists(&probe).expect("emptied"));

        // Whatever the answer, asking must not error, and the two arches must not both be wrong.
        let installed = target.arma_installed(BuildArch::X64);
        assert_eq!(installed, target.exists(&target.server_path.join("arma3server_x64")).unwrap());

        // Nothing running is the expected case and still a success.
        target.kill_arma().expect("kill_arma with no server running");

        target.run(&format!("rm -rf '{}'", scratch.display())).expect("cleanup");
    }
}
