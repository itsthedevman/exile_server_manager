use std::path::{Path, PathBuf};

use crate::error::BuildError;

const NOT_AVAILABLE: &str = "\
--target=windows with --start-server requires a remote agent running on the \
Windows host. Cross-compiled artifacts (.dll) can be built and packaged \
without --start-server. See docs/BUILD_SYSTEM_REWRITE.md for agent setup.";

/// Target implementation for remote Windows builds.
///
/// Construction succeeds so that artifact-only Windows builds (`bin/build
/// --target=windows` without `--start-server`) work end-to-end on Linux.
/// Any method that requires a live connection to a Windows host will fail
/// with a clear error until the agent is implemented.
#[allow(dead_code)]
pub struct RemoteTarget {
    build_path: PathBuf,
    server_path: PathBuf,
    server_args: String,
}

impl RemoteTarget {
    pub fn new() -> Result<Box<dyn super::Target>, BuildError> {
        Ok(Box::new(RemoteTarget {
            build_path: PathBuf::from("C:\\temp\\esm"),
            server_path: PathBuf::from("C:\\arma3server"),
            server_args: String::new(),
        }))
    }
}

impl super::Target for RemoteTarget {
    fn run(&self, _cmd: &str) -> Result<String, BuildError> {
        Err(BuildError::General(NOT_AVAILABLE.into()))
    }

    fn upload(&self, _local: &Path, _dest: &Path) -> Result<(), BuildError> {
        Err(BuildError::General(NOT_AVAILABLE.into()))
    }

    fn download(&self, _remote: &Path, _local: &Path) -> Result<(), BuildError> {
        Err(BuildError::General(NOT_AVAILABLE.into()))
    }

    fn exists(&self, _path: &Path) -> Result<bool, BuildError> {
        Err(BuildError::General(NOT_AVAILABLE.into()))
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
