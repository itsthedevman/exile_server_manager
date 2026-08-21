pub mod docker;
mod remote;

pub use docker::DockerTarget;
pub use remote::RemoteTarget;

use std::{path::Path, sync::Arc};

use crate::{
    config::{Config, Instance},
    context::{Args, BuildOS},
    error::BuildError,
};

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
