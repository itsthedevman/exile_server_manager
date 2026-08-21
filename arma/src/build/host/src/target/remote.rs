use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command as Cmd, Stdio};
use std::sync::Arc;

use crate::{
    config::{Config, Instance, WindowsConfig},
    error::BuildError,
};

/// Told to every ssh invocation.
///
/// Batch mode turns a missing key into an immediate error instead of a password prompt nobody is watching, since
/// the build runs behind a spinner. The connect timeout matters more than it looks: a guest on a NAT bridge with
/// a closed port drops packets rather than refusing them, so without this a wrong address hangs for minutes
/// looking like a slow build.
const SSH_OPTIONS: &[&str] = &[
    "-o",
    "BatchMode=yes",
    "-o",
    "ConnectTimeout=10",
    "-o",
    "LogLevel=ERROR",
];

/// Target implementation for a Windows host reached over SSH.
///
/// Commands go out as PowerShell rather than `cmd`, encoded rather than quoted. Windows' sshd hands a bare
/// command to `cmd.exe`, whose quoting rules differ from the local shell's, from PowerShell's, and from each
/// other depending on nesting depth; a server key or a path with a space stops surviving the trip long before
/// anything interesting is being run. `-EncodedCommand` takes UTF-16LE base64, so the command crosses as one
/// opaque token and none of those layers get a say.
pub struct RemoteTarget {
    build_path: PathBuf,
    server_path: PathBuf,
    server_args: String,
    destination: String,
    steamcmd_path: PathBuf,
}

impl RemoteTarget {
    pub fn new(config: &Config, instance: &Instance) -> Result<Arc<dyn super::Target>, BuildError> {
        let Some(windows) = config.windows.as_ref() else {
            return Err(BuildError::Config(
                "--target=windows needs a `windows:` section in config.yml naming the host to run on. Add:\n\
                 \n\
                 windows:\n\
                 \x20 host: <hostname or ssh alias>\n\
                 \x20 user: Administrator\n\
                 \n\
                 See config.example.yml for the optional keys."
                    .into(),
            ));
        };

        Ok(Arc::new(RemoteTarget {
            build_path: PathBuf::from("C:\\temp\\esm"),
            server_path: PathBuf::from(&windows.server_path),
            server_args: launch_args(windows, instance),
            destination: format!("{}@{}", windows.user, windows.host),
            steamcmd_path: PathBuf::from(&windows.steamcmd_path),
        }))
    }

    /// SteamCMD's install root on the target, which is installed by hand rather than bootstrapped.
    #[allow(dead_code)]
    pub fn steamcmd_path(&self) -> &Path {
        &self.steamcmd_path
    }

    /// Base64 a PowerShell script the way `-EncodedCommand` wants it: UTF-16LE, little end first.
    fn encode(script: &str) -> String {
        let utf16: Vec<u8> = script
            .encode_utf16()
            .flat_map(|unit| unit.to_le_bytes())
            .collect();

        base64_encode(&utf16)
    }

    fn ssh(&self) -> Cmd {
        let mut command = Cmd::new("ssh");
        command.args(SSH_OPTIONS).arg(&self.destination);
        command
    }
}

impl super::Target for RemoteTarget {
    fn run(&self, cmd: &str) -> Result<String, BuildError> {
        // Progress records are silenced at the top of every script. PowerShell writes them to the error stream,
        // and over a non-interactive session they arrive as CLIXML that would otherwise be read as failure output.
        let script = format!("$ProgressPreference = 'SilentlyContinue'\n{cmd}");

        let output = self
            .ssh()
            .args(["powershell", "-NoProfile", "-EncodedCommand", &Self::encode(&script)])
            .output()
            .map_err(|e| BuildError::Remote(e.to_string()))?;

        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let stdout = String::from_utf8_lossy(&output.stdout);
            return Err(BuildError::Remote(format!(
                "ssh {} failed (exit {}):\n{}\n{}",
                self.destination,
                output.status.code().unwrap_or(-1),
                stdout.trim(),
                stderr.trim()
            )));
        }

        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    }

    fn upload(&self, local: &Path, dest: &Path) -> Result<(), BuildError> {
        // Streamed as a tar through one ssh connection rather than copied with scp. `scp -r` disagrees with
        // itself about whether a `dir/.` source means the directory or its contents depending on which transfer
        // backend it picked, and the contents are what a deploy means; tar says so unambiguously. Windows has
        // shipped bsdtar in System32 since Windows 10 1803, so this needs nothing installed on the far side.
        self.run(&format!(
            "New-Item -ItemType Directory -Force -Path '{}' | Out-Null",
            dest.display()
        ))?;

        let mut sender = Cmd::new("tar")
            .args(["-cf", "-", "-C", &local.display().to_string(), "."])
            .stdout(Stdio::piped())
            .spawn()
            .map_err(|e| BuildError::Remote(e.to_string()))?;

        let Some(stream) = sender.stdout.take() else {
            return Err(BuildError::Remote("Could not read the upload stream".into()));
        };

        let receiver = self
            .ssh()
            .args(["tar", "-xf", "-", "-C", &dest.display().to_string()])
            .stdin(Stdio::from(stream))
            .output()
            .map_err(|e| BuildError::Remote(e.to_string()))?;

        sender.wait().map_err(|e| BuildError::Remote(e.to_string()))?;

        if !receiver.status.success() {
            return Err(BuildError::Remote(format!(
                "Upload of {} to {} failed: {}",
                local.display(),
                dest.display(),
                String::from_utf8_lossy(&receiver.stderr).trim()
            )));
        }

        Ok(())
    }

    fn download(&self, remote: &Path, local: &Path) -> Result<(), BuildError> {
        let output = Cmd::new("scp")
            .args(SSH_OPTIONS)
            .arg("-r")
            .arg(format!("{}:{}", self.destination, remote.display()))
            .arg(local.display().to_string())
            .output()
            .map_err(|e| BuildError::Remote(e.to_string()))?;

        if !output.status.success() {
            return Err(BuildError::Remote(format!(
                "Download of {} failed: {}",
                remote.display(),
                String::from_utf8_lossy(&output.stderr).trim()
            )));
        }

        Ok(())
    }

    fn exists(&self, path: &Path) -> Result<bool, BuildError> {
        let result = self.run(&format!(
            "if (Test-Path -LiteralPath '{}') {{ '1' }} else {{ '0' }}",
            path.display()
        ))?;

        Ok(result.trim() == "1")
    }

    fn write_file(&self, path: &Path, contents: &[u8]) -> Result<(), BuildError> {
        // Piped in over stdin and written by the shell on the far side, so the bytes never appear in a command
        // line. Server keys are the reason: they hold whatever the bot generated, and a build that only works
        // for keys without quotes in them is a build that fails once a month for no visible reason.
        let script = format!(
            "$ProgressPreference = 'SilentlyContinue'\n\
             New-Item -ItemType Directory -Force -Path (Split-Path -Parent '{path}') | Out-Null\n\
             $stdin = [Console]::OpenStandardInput()\n\
             $file = [IO.File]::Create('{path}')\n\
             $stdin.CopyTo($file)\n\
             $file.Close()",
            path = path.display()
        );

        let mut child = self
            .ssh()
            .args(["powershell", "-NoProfile", "-EncodedCommand", &Self::encode(&script)])
            .stdin(Stdio::piped())
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| BuildError::Remote(e.to_string()))?;

        if let Some(mut stdin) = child.stdin.take() {
            stdin
                .write_all(contents)
                .map_err(|e| BuildError::Remote(e.to_string()))?;
        }

        let output = child
            .wait_with_output()
            .map_err(|e| BuildError::Remote(e.to_string()))?;

        if !output.status.success() {
            return Err(BuildError::Remote(format!(
                "Failed to write {} on {}: {}",
                path.display(),
                self.destination,
                String::from_utf8_lossy(&output.stderr).trim()
            )));
        }

        Ok(())
    }

    fn clear_directory(&self, path: &Path) -> Result<(), BuildError> {
        self.run(&format!(
            "New-Item -ItemType Directory -Force -Path '{path}' | Out-Null\n\
             Get-ChildItem -LiteralPath '{path}' -Force | Remove-Item -Recurse -Force",
            path = path.display()
        ))?;

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

/// Assemble the launch arguments, falling back to nothing rather than to the Linux ones.
///
/// The two shells disagree about semicolons, which `-mod=` and `-servermod=` are full of: the Linux arguments
/// carry backslash escapes that arrive on Windows as literal backslashes and name mods that do not exist. A
/// server that starts with no mods looks like a broken build, so an unconfigured Windows host gets bare
/// arguments and says as much through the missing mods rather than through a silently mangled command line.
fn launch_args(windows: &WindowsConfig, instance: &Instance) -> String {
    windows
        .server_args
        .iter()
        .map(|arg| format!("-{arg}"))
        .chain(std::iter::once(format!("-port={}", instance.port)))
        .collect::<Vec<_>>()
        .join(" ")
}

/// Standard base64, written out rather than pulled in: one call site, and the alternative is a dependency.
fn base64_encode(bytes: &[u8]) -> String {
    const ALPHABET: &[u8; 64] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

    let mut encoded = String::with_capacity(bytes.len().div_ceil(3) * 4);

    for chunk in bytes.chunks(3) {
        let bits = chunk
            .iter()
            .enumerate()
            .fold(0u32, |acc, (index, byte)| acc | (*byte as u32) << (16 - index * 8));

        encoded.push(ALPHABET[(bits >> 18 & 0x3F) as usize] as char);
        encoded.push(ALPHABET[(bits >> 12 & 0x3F) as usize] as char);
        encoded.push(if chunk.len() > 1 {
            ALPHABET[(bits >> 6 & 0x3F) as usize] as char
        } else {
            '='
        });
        encoded.push(if chunk.len() > 2 {
            ALPHABET[(bits & 0x3F) as usize] as char
        } else {
            '='
        });
    }

    encoded
}

#[cfg(test)]
mod tests {
    use super::base64_encode;
    use crate::config::parse;

    #[test]
    fn base64_pads_every_chunk_length() {
        assert_eq!(base64_encode(b""), "");
        assert_eq!(base64_encode(b"f"), "Zg==");
        assert_eq!(base64_encode(b"fo"), "Zm8=");
        assert_eq!(base64_encode(b"foo"), "Zm9v");
        assert_eq!(base64_encode(b"foob"), "Zm9vYg==");
        assert_eq!(base64_encode(b"fooba"), "Zm9vYmE=");
        assert_eq!(base64_encode(b"foobar"), "Zm9vYmFy");
    }

    #[test]
    fn encode_produces_utf16le_base64() {
        // `dir` as UTF-16LE is 64 00 69 00 72 00, which is what PowerShell's -EncodedCommand expects.
        assert_eq!(super::RemoteTarget::encode("dir"), "ZABpAHIA");
    }

    /// Smoke test for the transport against the host named in `config.yml`.
    ///
    /// Ignored by default because it needs that host up and reachable. Run it after changing anything in this
    /// file: every failure mode here (a quoting layer eating a character, a tar that copied the directory
    /// instead of its contents) otherwise surfaces much later as a build step failing for no visible reason.
    ///
    ///   cargo test -p host -- --ignored --nocapture
    #[test]
    #[ignore = "needs the Windows host from config.yml to be reachable"]
    fn transport_round_trips_against_the_configured_host() {
        // Tests run with the crate directory as the working directory, not the repo root where config.yml lives.
        let config_path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../config.yml");
        let config = parse(std::path::Path::new(config_path)).expect("config.yml");
        let instance = config.instances[0].clone();
        let target = super::RemoteTarget::new(&config, &instance).expect("windows: section");

        assert_eq!(target.run("'hello'").expect("run"), "hello");

        // Quoting is the whole risk, so the probe carries the characters that break each layer.
        let awkward = "quote \" backslash \\ dollar $ semi ; newline\n";
        let remote = std::path::Path::new("C:\\temp\\esm-transport-test.txt");
        target.write_file(remote, awkward.as_bytes()).expect("write_file");

        assert!(target.exists(remote).expect("exists"));

        let read_back = target
            .run(&format!("[IO.File]::ReadAllText('{}')", remote.display()))
            .expect("read back");
        assert_eq!(read_back.trim_end(), awkward.trim_end());

        target
            .run(&format!("Remove-Item -LiteralPath '{}' -Force", remote.display()))
            .expect("cleanup");
        assert!(!target.exists(remote).expect("exists after delete"));
    }

    /// Uploading must land the directory's *contents* at the destination, not the directory itself.
    ///
    /// A deploy empties `@esm` and then fills it. Getting this wrong nests everything one level deeper, which
    /// Arma reports as a mod that loaded with none of its files rather than as a failed copy.
    #[test]
    #[ignore = "needs the Windows host from config.yml to be reachable"]
    fn upload_lands_contents_not_the_directory() {
        let config_path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../config.yml");
        let config = parse(std::path::Path::new(config_path)).expect("config.yml");
        let instance = config.instances[0].clone();
        let target = super::RemoteTarget::new(&config, &instance).expect("windows: section");

        let local = std::env::temp_dir().join("esm-upload-test");
        let nested = local.join("addons");
        std::fs::create_dir_all(&nested).expect("local tree");
        std::fs::write(local.join("top.txt"), b"top").expect("top");
        std::fs::write(nested.join("inner.txt"), b"inner").expect("inner");

        let remote = std::path::Path::new("C:\\temp\\esm-upload-test");
        target.clear_directory(remote).expect("clear");
        target.upload(&local, remote).expect("upload");

        assert!(
            target.exists(&remote.join("top.txt")).expect("top exists"),
            "the directory was uploaded instead of its contents"
        );
        assert!(target.exists(&remote.join("addons").join("inner.txt")).expect("nested exists"));

        // clear_directory has to leave the directory standing, since on Linux it is a bind mount.
        target.clear_directory(remote).expect("clear again");
        assert!(target.exists(remote).expect("root survives"));
        assert!(!target.exists(&remote.join("top.txt")).expect("emptied"));

        std::fs::remove_dir_all(&local).ok();
        target
            .run(&format!("Remove-Item -LiteralPath '{}' -Recurse -Force", remote.display()))
            .expect("cleanup");
    }
}
