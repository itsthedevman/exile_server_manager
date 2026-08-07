pub mod docker;
mod remote;

pub use docker::DockerTarget;
pub use remote::RemoteTarget;

use std::path::Path;

use crate::{
    config::{Config, Instance},
    context::{Args, BuildOS},
    error::BuildError,
};

/// Abstracts where build commands execute and where files live.
#[allow(dead_code)]
pub trait Target: Send + Sync {
    /// Run a shell command in the target environment, return stdout.
    fn run(&self, cmd: &str) -> Result<String, BuildError>;

    /// Copy the contents of the local directory `local` into the directory `dest` on the target.
    fn upload(&self, local: &Path, dest: &Path) -> Result<(), BuildError>;

    /// Copy a path from the target to a local destination.
    fn download(&self, remote: &Path, local: &Path) -> Result<(), BuildError>;

    /// Check whether a path exists on the target.
    fn exists(&self, path: &Path) -> Result<bool, BuildError>;

    /// Staging area root on the target (e.g. `/tmp/esm`).
    fn build_path(&self) -> &Path;

    /// Arma 3 server root on the target (e.g. `/arma3server`).
    fn server_path(&self) -> &Path;

    /// Arma 3 server launch argument string.
    fn server_args(&self) -> &str;
}

pub fn build_target(
    args: &Args,
    config: &Config,
    instance: &Instance,
) -> Result<Box<dyn Target>, BuildError> {
    match args.build_os() {
        BuildOS::Linux => Ok(Box::new(DockerTarget::new(config, instance))),
        BuildOS::Windows => RemoteTarget::new(),
    }
}
