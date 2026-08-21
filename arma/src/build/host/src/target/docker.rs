use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command as Cmd, Stdio};

use crate::{
    config::{Config, Instance},
    error::BuildError,
};

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
