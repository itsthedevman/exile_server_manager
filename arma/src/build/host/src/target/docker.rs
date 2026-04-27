use std::path::{Path, PathBuf};
use std::process::Command as Cmd;

use crate::{config::Config, error::BuildError, ARMA_CONTAINER, ARMA_SERVICE};

pub struct DockerTarget {
    #[allow(dead_code)]
    build_path: PathBuf,
    server_path: PathBuf,
    server_args: String,
}

impl DockerTarget {
    pub fn new(config: &Config) -> Self {
        let server_args = config
            .server
            .server_args
            .iter()
            .map(|arg| format!("-{arg}"))
            .collect::<Vec<_>>()
            .join(" ");

        DockerTarget {
            build_path: PathBuf::from("/tmp/esm"),
            server_path: PathBuf::from(crate::ARMA_PATH),
            server_args,
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
                ARMA_CONTAINER,
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
        let dest_str = format!("{}:{}", ARMA_SERVICE, dest.display());

        let output = Cmd::new("docker")
            .args(["compose", "cp", &local.display().to_string(), &dest_str])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        if !output.status.success() {
            let msg = String::from_utf8_lossy(&output.stderr);
            return Err(BuildError::Docker(format!(
                "docker compose cp upload failed: {}",
                msg.trim()
            )));
        }

        Ok(())
    }

    fn download(&self, remote: &Path, local: &Path) -> Result<(), BuildError> {
        let src_str = format!("{}:{}", ARMA_SERVICE, remote.display());

        let output = Cmd::new("docker")
            .args(["compose", "cp", &src_str, &local.display().to_string()])
            .output()
            .map_err(|e| BuildError::Docker(e.to_string()))?;

        if !output.status.success() {
            let msg = String::from_utf8_lossy(&output.stderr);
            return Err(BuildError::Docker(format!(
                "docker compose cp download failed: {}",
                msg.trim()
            )));
        }

        Ok(())
    }

    fn exists(&self, path: &Path) -> Result<bool, BuildError> {
        let output = Cmd::new("docker")
            .args([
                "exec",
                "-t",
                ARMA_CONTAINER,
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
