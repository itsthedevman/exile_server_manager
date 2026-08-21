pub mod docker;
mod remote;

pub use docker::DockerTarget;
pub use remote::RemoteTarget;

use std::{collections::HashMap, io::Read, path::{Path, PathBuf}, sync::Arc};

use crate::{
    config::{Config, Instance},
    context::{Args, BuildArch, BuildOS},
    error::BuildError,
};

/// Frames [`Target::read_appended`]: one `<separator>:<path>:<size>` line, then that file's new bytes.
///
/// One round trip carries every file that grew, because the alternative is a round trip per file per poll and
/// the poll interval is measured in milliseconds. Both targets emit it; the reader in `steps::logs` parses it.
pub const LOG_FRAME_SEPARATOR: &str = "__ESM_FILE__";

/// Abstracts where build commands execute and where files live.
///
/// Two kinds of method live here. Transport (`upload`, `download`, `write_file`) works the same everywhere and
/// only differs in how bytes get across. Anything taking a shell command does not: `run` speaks bash against a
/// container and PowerShell against a Windows host, so a step that composes one is writing for a single target
/// whether it means to or not. Prefer the named operations below and keep `run` for the genuinely one-off.
#[allow(dead_code)]
pub trait Target: Send + Sync {
    /// Run a shell command in the target environment, return stdout.
    ///
    /// The dialect is the target's own. A caller that hardcodes one is not portable, which is the reason the
    /// operations every step needs have their own methods.
    fn run(&self, cmd: &str) -> Result<String, BuildError>;

    /// Copy the contents of the local directory `local` into the directory `dest` on the target.
    fn upload(&self, local: &Path, dest: &Path) -> Result<(), BuildError>;

    /// Copy a path from the target to a local destination.
    fn download(&self, remote: &Path, local: &Path) -> Result<(), BuildError>;

    /// Check whether a path exists on the target.
    fn exists(&self, path: &Path) -> Result<bool, BuildError>;

    /// Write `contents` to `path` on the target, creating or truncating it.
    ///
    /// The bytes travel out of band rather than inside a command string, because server keys and rendered config
    /// hold quotes, backslashes and newlines that no amount of escaping survives on both shells.
    fn write_file(&self, path: &Path, contents: &[u8]) -> Result<(), BuildError>;

    /// Empty `path` of its contents, creating it if absent, without removing the directory itself.
    ///
    /// The directory has to survive on Linux, where it is a bind mount whose mount point cannot be unlinked from
    /// inside the container. Windows has no such constraint, but keeping one meaning for the operation is what
    /// lets the steps stay target-agnostic.
    fn clear_directory(&self, path: &Path) -> Result<(), BuildError>;

    /// Install or update the Arma 3 dedicated server through SteamCMD.
    ///
    /// Credentials are required, not optional: `app_update 233780` under an anonymous login is refused an app
    /// access token and fails as `Missing configuration`, which reads like a broken install rather than a
    /// missing password.
    ///
    /// Output is handed to `on_line` as it arrives rather than returned at the end. A validating download of a
    /// 5GB install is minutes of silence otherwise, which is indistinguishable from a hang.
    fn install_arma(
        &self,
        steam_user: &str,
        steam_password: &str,
        on_line: &mut dyn FnMut(&str),
    ) -> Result<(), BuildError>;

    /// Whether the Arma 3 server binary for `arch` is already on the target.
    fn arma_installed(&self, arch: BuildArch) -> bool;

    /// Stop any running Arma 3 server, and the watchdog guarding it.
    ///
    /// Nothing running is a success. Every caller either just asked for a clean slate or is on the way out.
    fn kill_arma(&self) -> Result<(), BuildError>;

    /// Remove the logs, RPTs and crash dumps left by the previous run.
    fn clean_logs(&self) -> Result<(), BuildError>;

    /// Launch the Arma 3 server, recording the PID for [`Target::kill_arma`] and starting the watchdog that
    /// reaps it once [`Target::heartbeat`] stops being called.
    fn start_arma(&self, arch: BuildArch) -> Result<(), BuildError>;

    /// Mark the build process as still alive, so the target-side watchdog leaves the server running.
    ///
    /// The watchdog is what stops an Arma server outliving the build that started it, however that build died:
    /// Ctrl-C, a closed terminal, or a signal nothing can catch. The build calls this on a loop; the target
    /// decides what going quiet means.
    fn heartbeat(&self) -> Result<(), BuildError>;

    /// Find the log files that only exist once a server has run.
    ///
    /// `rpt_dir` is scanned one level deep for Arma's `.rpt` files; every entry in `log_dirs` is searched
    /// recursively for `.log` files. Discovered rather than listed by name so that a component gaining a log
    /// starts being followed without anything here knowing it exists.
    fn discover_logs(&self, rpt_dir: &Path, log_dirs: &[&Path]) -> Vec<PathBuf>;

    /// Read whatever was appended to each file past its recorded offset, in a single round trip.
    ///
    /// Returns the framed output described by [`LOG_FRAME_SEPARATOR`], or `None` when nothing grew.
    fn read_appended(
        &self,
        files: &[&PathBuf],
        offsets: &HashMap<PathBuf, u64>,
    ) -> Option<String>;

    /// Staging area root on the target (e.g. `/tmp/esm`).
    fn build_path(&self) -> &Path;

    /// Arma 3 server root on the target (e.g. `/arma3server`).
    fn server_path(&self) -> &Path;

    /// Arma 3 server launch argument string.
    fn server_args(&self) -> &str;
}

/// Hands back an `Arc` rather than a `Box` because the key exchange keeps writing files from a background
/// thread that outlives the step which started it, and so needs its own handle on the target.
pub fn build_target(
    args: &Args,
    config: &Config,
    instance: &Instance,
) -> Result<Arc<dyn Target>, BuildError> {
    match args.build_os() {
        BuildOS::Linux => Ok(Arc::new(DockerTarget::new(config, instance))),
        BuildOS::Windows => RemoteTarget::new(config, instance),
    }
}

/// Read `reader` to exhaustion, handing each line to `on_line` as it arrives.
///
/// Splits on carriage returns as well as newlines. SteamCMD reports download progress by rewriting a single
/// line with `\r` and no newline until it finishes, so splitting only on `\n` would buffer the entire download
/// and deliver it in one piece at the end, which is precisely when nobody needs it any more.
pub fn stream_lines(mut reader: impl Read, on_line: &mut dyn FnMut(&str)) {
    let mut buffer = [0u8; 4096];
    let mut line = Vec::new();

    loop {
        let read = match reader.read(&mut buffer) {
            Ok(0) | Err(_) => break,
            Ok(read) => read,
        };

        for byte in &buffer[..read] {
            match byte {
                b'\n' | b'\r' => {
                    if !line.is_empty() {
                        on_line(String::from_utf8_lossy(&line).trim_end());
                        line.clear();
                    }
                }
                _ => line.push(*byte),
            }
        }
    }

    if !line.is_empty() {
        on_line(String::from_utf8_lossy(&line).trim_end());
    }
}

#[cfg(test)]
mod tests {
    use super::stream_lines;

    fn collect(input: &[u8]) -> Vec<String> {
        let mut lines = Vec::new();
        stream_lines(input, &mut |line| lines.push(line.to_string()));
        lines
    }

    #[test]
    fn splits_on_carriage_returns_so_progress_arrives_while_it_matters() {
        // How SteamCMD reports a download: one line rewritten, no newline until it is finished.
        let raw = b"progress: 12.34\rprogress: 56.78\rprogress: 100.00\nSuccess!\n";
        assert_eq!(
            collect(raw),
            vec!["progress: 12.34", "progress: 56.78", "progress: 100.00", "Success!"]
        );
    }

    #[test]
    fn treats_crlf_as_one_break_rather_than_two() {
        assert_eq!(collect(b"alpha\r\nbeta\r\n"), vec!["alpha", "beta"]);
    }

    #[test]
    fn emits_a_trailing_line_that_was_never_terminated() {
        assert_eq!(collect(b"no newline at the end"), vec!["no newline at the end"]);
    }

    #[test]
    fn nothing_in_nothing_out() {
        assert!(collect(b"").is_empty());
        assert!(collect(b"\r\n\r\n").is_empty());
    }

    #[test]
    fn reassembles_a_line_split_across_reads() {
        // The reader hands back 4096 bytes at a time, so a long line arrives in pieces and must not be split.
        let long = "x".repeat(10_000);
        let raw = format!("{long}\n");
        assert_eq!(collect(raw.as_bytes()), vec![long]);
    }
}
