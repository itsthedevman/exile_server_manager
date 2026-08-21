use std::collections::HashMap;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command as Cmd, Stdio};
use std::sync::Arc;

use crate::{
    config::{Config, Instance, WindowsConfig},
    context::BuildArch,
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
    // One connection, reused. A build makes hundreds of round trips and the heartbeat adds one every few
    // seconds for as long as the server runs; without multiplexing each is a full key exchange, which costs
    // more than everything it carries. The socket is dropped shortly after the last user goes away.
    "-o",
    "ControlMaster=auto",
    "-o",
    "ControlPath=/tmp/esm-build-%r@%h:%p",
    "-o",
    "ControlPersist=60",
];

// Mirrors the container's bookkeeping. Same mechanism, same meaning, different spelling: the build refreshes
// the heartbeat while it lives, and a watchdog on the far side kills the server once it goes stale.
const HEARTBEAT_FILE: &str = "C:\\temp\\esm_heartbeat";
const SERVER_PID_FILE: &str = "C:\\temp\\esm_server.pid";
const WATCHDOG_PID_FILE: &str = "C:\\temp\\esm_watchdog.pid";
const HEARTBEAT_STALE_SECS: u64 = 15;
const HEARTBEAT_POLL_SECS: u64 = 3;

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

    fn install_arma(&self, steam_user: &str, steam_password: &str) -> Result<(), BuildError> {
        // SteamCMD is expected to already be installed. The Linux container bootstraps its own because the image
        // ships without one; a Windows host is set up by hand, and silently downloading an installer onto it is
        // a bigger liberty than saying where to put one.
        let steamcmd = self.steamcmd_path.join("steamcmd.exe");

        if !self.exists(&steamcmd)? {
            return Err(BuildError::Remote(format!(
                "No steamcmd.exe at {}. Install SteamCMD on the Windows host, or point \
                 `windows.steamcmd_path` in config.yml at where it already lives.",
                steamcmd.display()
            )));
        }

        // force_install_dir has to precede app_update or it is ignored, and the login cannot be anonymous:
        // 233780 refuses an anonymous app access token and reports it as `Missing configuration`.
        self.run(&format!(
            "& {steamcmd} +force_install_dir {server} +login {user} {password} \
             +app_update 233780 validate +quit",
            steamcmd = ps_literal(&steamcmd.display().to_string()),
            server = ps_literal(&self.server_path.display().to_string()),
            user = ps_literal(steam_user),
            password = ps_literal(steam_password),
        ))?;

        Ok(())
    }

    fn arma_installed(&self, arch: BuildArch) -> bool {
        self.exists(&self.server_path.join(arma_executable(arch)))
            .unwrap_or(false)
    }

    fn kill_arma(&self) -> Result<(), BuildError> {
        let names = ARMA_PROCESS_NAMES
            .iter()
            .map(|name| ps_literal(name))
            .collect::<Vec<_>>()
            .join(",");

        // By name rather than by the recorded PID, because a server that outlived its watchdog has no readable
        // record left and is exactly the one that needs killing.
        self.run(&format!(
            "Get-Process -Name {names} -ErrorAction SilentlyContinue | Stop-Process -Force\n\
             if (Test-Path -LiteralPath {wpid}) {{\n\
             \x20 Get-Content -LiteralPath {wpid} | ForEach-Object {{ Stop-Process -Id $_ -Force -ErrorAction SilentlyContinue }}\n\
             }}\n\
             Remove-Item -LiteralPath {hb},{spid},{wpid} -Force -ErrorAction SilentlyContinue",
            hb = ps_literal(HEARTBEAT_FILE),
            spid = ps_literal(SERVER_PID_FILE),
            wpid = ps_literal(WATCHDOG_PID_FILE),
        ))
        .ok(); // nothing running is the expected case, not a failure

        Ok(())
    }

    fn clean_logs(&self) -> Result<(), BuildError> {
        let profile = self.server_path.join("server_profile");

        self.run(&format!(
            // @esm/log is cleaned too, and it is the one that used to be missed. A deploy empties @esm and so
            // hid this, but --start-only deliberately skips the deploy, leaving a log the streamer then replayed
            // from the top: every run reprinting the last one before showing anything new.
            "Get-ChildItem -LiteralPath {profile} -Include *.log,*.rpt,*.bidmp,*.mdmp,*.txt -Recurse \
                 -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue\n\
             Get-ChildItem -LiteralPath {esm_logs} -Filter *.log -File \
                 -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue\n\
             Remove-Item -LiteralPath {logs} -Recurse -Force -ErrorAction SilentlyContinue",
            profile = ps_literal(&profile.display().to_string()),
            esm_logs = ps_literal(&self.server_path.join("@esm").join("log").display().to_string()),
            logs = ps_literal(&self.server_path.join("@exileserver").join("logs").display().to_string()),
        ))
        .ok(); // best effort: a first run has nothing to clean

        Ok(())
    }

    fn start_arma(&self, arch: BuildArch) -> Result<(), BuildError> {
        let exe = self.server_path.join(arma_executable(arch));

        // The watchdog is encoded here and embedded as one base64 token, rather than nested as a quoted string
        // inside the outer script. Two layers of PowerShell quoting around a script holding both kinds of quote
        // is the sort of thing that works until an argument changes.
        let watchdog = Self::encode(&format!(
            "$target = [int](Get-Content -LiteralPath {spid})\n\
             while ($true) {{\n\
             \x20 Start-Sleep -Seconds {poll}\n\
             \x20 $beat = if (Test-Path -LiteralPath {hb}) {{ (Get-Item -LiteralPath {hb}).LastWriteTimeUtc }} \
                 else {{ [DateTime]::MinValue }}\n\
             \x20 if (((Get-Date).ToUniversalTime() - $beat).TotalSeconds -ge {stale}) {{\n\
             \x20\x20 Stop-Process -Id $target -Force -ErrorAction SilentlyContinue\n\
             \x20\x20 Remove-Item -LiteralPath {hb},{spid},{wpid} -Force -ErrorAction SilentlyContinue\n\
             \x20\x20 exit\n\
             \x20 }}\n\
             }}",
            hb = ps_literal(HEARTBEAT_FILE),
            spid = ps_literal(SERVER_PID_FILE),
            wpid = ps_literal(WATCHDOG_PID_FILE),
            poll = HEARTBEAT_POLL_SECS,
            stale = HEARTBEAT_STALE_SECS,
        ));

        // Launched through WMI rather than Start-Process, and this is not a style choice. Windows' sshd puts
        // each session in a job object and kills the whole tree when the session ends, so anything started the
        // obvious way dies the moment this command returns: the build reports a server started, and there is no
        // server. Win32_Process.Create is serviced by the WMI provider host, outside that job, so what it
        // spawns outlives the session that asked for it.
        self.run(&format!(
            "New-Item -ItemType Directory -Force -Path {profile} | Out-Null\n\
             New-Item -ItemType Directory -Force -Path (Split-Path -Parent {hb}) | Out-Null\n\
             Set-Content -LiteralPath {hb} -Value ''\n\
             $server = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{{\n\
             \x20 CommandLine = {command}\n\
             \x20 CurrentDirectory = {server}\n\
             }}\n\
             if ($server.ReturnValue -ne 0) {{ throw \"Win32_Process.Create failed: $($server.ReturnValue)\" }}\n\
             Set-Content -LiteralPath {spid} -Value $server.ProcessId\n\
             $watchdog = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{{\n\
             \x20 CommandLine = 'powershell.exe -NoProfile -EncodedCommand {watchdog}'\n\
             }}\n\
             Set-Content -LiteralPath {wpid} -Value $watchdog.ProcessId",
            profile = ps_literal(&self.server_path.join("server_profile").display().to_string()),
            command = ps_literal(&format!("\"{}\" {}", exe.display(), self.server_args)),
            server = ps_literal(&self.server_path.display().to_string()),
            hb = ps_literal(HEARTBEAT_FILE),
            spid = ps_literal(SERVER_PID_FILE),
            wpid = ps_literal(WATCHDOG_PID_FILE),
        ))?;

        Ok(())
    }

    fn heartbeat(&self) -> Result<(), BuildError> {
        self.run(&format!(
            "Set-Content -LiteralPath {hb} -Value ''",
            hb = ps_literal(HEARTBEAT_FILE)
        ))?;

        Ok(())
    }

    fn discover_logs(&self, rpt_dir: &Path, log_dirs: &[&Path]) -> Vec<PathBuf> {
        // RPTs sit directly in the profile directory; extDB nests its own under a dated tree, so only the
        // log searches recurse. All of them stay silent when the directory does not exist yet, which is the
        // normal state until a server has run once.
        let mut script = format!(
            "Get-ChildItem -LiteralPath {rpt} -Filter *.rpt -File -ErrorAction SilentlyContinue | \
                 ForEach-Object {{ $_.FullName }}\n",
            rpt = ps_literal(&rpt_dir.display().to_string()),
        );

        for dir in log_dirs {
            script.push_str(&format!(
                "Get-ChildItem -LiteralPath {dir} -Filter *.log -File -Recurse \
                     -ErrorAction SilentlyContinue | ForEach-Object {{ $_.FullName }}\n",
                dir = ps_literal(&dir.display().to_string()),
            ));
        }

        let listing = self.run(&script);

        listing
            .unwrap_or_default()
            .lines()
            .filter(|line| !line.trim().is_empty())
            .map(PathBuf::from)
            .collect()
    }

    fn read_appended(
        &self,
        files: &[&PathBuf],
        offsets: &HashMap<PathBuf, u64>,
    ) -> Option<String> {
        if files.is_empty() {
            return None;
        }

        let separator = crate::target::LOG_FRAME_SEPARATOR;
        let script: String = files
            .iter()
            .map(|path| {
                let offset = offsets.get(*path).copied().unwrap_or(0);
                let quoted = ps_literal(&path.display().to_string());

                // FileShare.ReadWrite is the whole reason this opens a stream by hand rather than calling
                // Get-Content. Arma holds its RPT open while it runs, and Windows refuses a second handle
                // unless the reader explicitly tolerates the writer, so anything simpler reads nothing at all
                // for exactly as long as there is something worth reading.
                format!(
                    "if (Test-Path -LiteralPath {quoted}) {{\n\
                     \x20 $length = (Get-Item -LiteralPath {quoted}).Length\n\
                     \x20 if ($length -gt {offset}) {{\n\
                     \x20\x20 \"{separator}:$({quoted}):$length\"\n\
                     \x20\x20 $stream = [IO.File]::Open({quoted}, 'Open', 'Read', 'ReadWrite')\n\
                     \x20\x20 $stream.Seek({offset}, 'Begin') | Out-Null\n\
                     \x20\x20 $buffer = New-Object byte[] ($length - {offset})\n\
                     \x20\x20 $read = $stream.Read($buffer, 0, $buffer.Length)\n\
                     \x20\x20 $stream.Close()\n\
                     \x20\x20 [Text.Encoding]::UTF8.GetString($buffer, 0, $read)\n\
                     \x20 }}\n\
                     }}\n"
                )
            })
            .collect();

        let raw = self.run(&script).ok()?;

        if raw.trim().is_empty() { None } else { Some(raw) }
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

/// Process names to stop, without the `.exe`, which is how `Get-Process` names them.
const ARMA_PROCESS_NAMES: &[&str] = &["arma3server", "arma3server_x64"];

fn arma_executable(arch: BuildArch) -> &'static str {
    match arch {
        BuildArch::X32 => "arma3server.exe",
        BuildArch::X64 => "arma3server_x64.exe",
    }
}

/// Wrap a value as a PowerShell single-quoted string.
///
/// Single quotes because PowerShell expands `$` and backticks inside double-quoted ones, and paths and launch
/// arguments hold both. Doubling is how a literal single quote is written inside one, which is the only escape
/// the form has and the only one needed.
fn ps_literal(value: &str) -> String {
    format!("'{}'", value.replace('\'', "''"))
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

    /// Reading a log Arma still holds open is the whole reason `read_appended` opens a stream by hand.
    ///
    /// Windows refuses a second handle to an open file unless the reader tolerates the existing writer, so a
    /// writer is held open across the read here. Drop `FileShare.ReadWrite` from `read_appended` and this must
    /// fail; if it still passes, the test is reading a leftover file rather than a locked one, which is exactly
    /// what happened the first time it was written.
    ///
    /// The writer is spawned through WMI for the same reason `start_arma` is: a process started any other way
    /// over SSH is killed with the session that started it, and would already be gone by the time the next
    /// command connects to check on it.
    #[test]
    #[ignore = "needs the Windows host from config.yml to be reachable"]
    fn read_appended_can_read_a_file_held_open_by_another_process() {
        use std::collections::HashMap;

        let config_path = concat!(env!("CARGO_MANIFEST_DIR"), "/../../../config.yml");
        let config = parse(std::path::Path::new(config_path)).expect("config.yml");
        let instance = config.instances[0].clone();
        let target = super::RemoteTarget::new(&config, &instance).expect("windows: section");

        let log = std::path::PathBuf::from("C:\\temp\\esm-held-open.log");
        let holder_script = "C:\\temp\\esm-holder.ps1";

        // Start from nothing, or a file left behind by an earlier run makes the whole test vacuous. The
        // delete is allowed to fail (PowerShell exits non-zero even for a suppressed error); the assertion
        // below is what actually has to hold.
        target
            .run(&format!(
                "Remove-Item -LiteralPath '{path}' -Force -ErrorAction SilentlyContinue",
                path = log.display()
            ))
            .ok();
        assert!(
            !target.exists(&log).expect("exists"),
            "a leftover log would let this pass without anything holding it open"
        );

        // FileShare.Read: other processes may read it, but only if they permit this writer to keep writing.
        // That is the condition read_appended has to satisfy, and it is how arma3server holds its RPT.
        let holder_pid = target
            .run(&format!(
                "$holder = @'\n\
                 $file = [IO.File]::Open('{path}', 'Create', 'Write', 'Read')\n\
                 $bytes = [Text.Encoding]::UTF8.GetBytes('held open')\n\
                 $file.Write($bytes, 0, $bytes.Length)\n\
                 $file.Flush()\n\
                 Start-Sleep -Seconds 30\n\
                 $file.Close()\n\
                 '@\n\
                 New-Item -ItemType Directory -Force -Path 'C:\\temp' | Out-Null\n\
                 Set-Content -LiteralPath '{script}' -Value $holder\n\
                 $p = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{{\n\
                 \x20 CommandLine = 'powershell.exe -NoProfile -File {script}'\n\
                 }}\n\
                 Start-Sleep -Seconds 3\n\
                 $p.ProcessId",
                path = log.display(),
                script = holder_script,
            ))
            .expect("start holder");

        let holder_pid: u32 = holder_pid.trim().parse().expect("holder pid");

        // The writer has to still be alive at the moment of the read, or there is no lock to work around.
        let alive = target
            .run(&format!(
                "if (Get-Process -Id {holder_pid} -ErrorAction SilentlyContinue) {{ '1' }} else {{ '0' }}"
            ))
            .expect("holder liveness");
        assert_eq!(alive.trim(), "1", "the holder exited before the read, so nothing was locked");

        let files = vec![&log];
        let offsets: HashMap<std::path::PathBuf, u64> = HashMap::new();

        let raw = target
            .read_appended(&files, &offsets)
            .expect("a file held open by a writer must still be readable");
        assert!(raw.contains("held open"), "expected the contents, got: {raw}");

        target
            .run(&format!(
                "Stop-Process -Id {holder_pid} -Force -ErrorAction SilentlyContinue\n\
                 Start-Sleep -Milliseconds 500\n\
                 Remove-Item -LiteralPath '{path}','{script}' -Force -ErrorAction SilentlyContinue",
                path = log.display(),
                script = holder_script,
            ))
            .ok();
    }
}
