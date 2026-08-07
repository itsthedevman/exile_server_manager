use std::fs::{self, File};
use std::path::Path;

use fs2::FileExt;

use crate::error::BuildError;

/// Exclusive hold on the shared build tree, released when dropped.
pub struct BuildLock {
    file: File,
}

impl BuildLock {
    /// Take the lock, waiting for whichever run holds it to finish.
    ///
    /// Servers are otherwise independent enough to run one `bin/build` per terminal, but they all compile the
    /// mod and the extension into the same `target/@esm`. Without this, starting two at once lets one wipe
    /// the staging tree from under the other's deploy.
    pub fn acquire(local_build_path: &Path) -> Result<Self, BuildError> {
        fs::create_dir_all(local_build_path)?;

        let file = File::create(local_build_path.join(".build.lock"))?;

        if file.try_lock_exclusive().is_err() {
            println!("  Waiting for another build to finish...");
            file.lock_exclusive()?;
        }

        Ok(BuildLock { file })
    }
}

impl Drop for BuildLock {
    fn drop(&mut self) {
        // The OS releases the lock when the file closes, so a crashed build can't leave it held.
        let _ = FileExt::unlock(&self.file);
    }
}

/// Exclusive claim on one server, released when dropped.
pub struct ServerLock {
    file: File,
}

impl ServerLock {
    /// Take the lock, or report which server is already spoken for.
    ///
    /// Two runs aimed at the same server fight over one container: the second `docker compose up` recreates
    /// it, killing the first run's server, and both host processes then heartbeat a container neither of them
    /// fully owns. Different servers never collide, so this only rejects the overlap.
    ///
    /// Unlike [`BuildLock`] this refuses rather than queues. A dev server runs until its terminal closes, so
    /// waiting for one to release means waiting for something that will not happen on its own.
    pub fn acquire(instance_staging_path: &Path, server_id: &str) -> Result<Self, BuildError> {
        fs::create_dir_all(instance_staging_path)?;

        let file = File::create(instance_staging_path.join(".server.lock"))?;

        if file.try_lock_exclusive().is_err() {
            return Err(BuildError::General(format!(
                "{server_id} is already being run by another bin/build. Stop that one first, or pass \
                 --server-id to run a different server alongside it."
            )));
        }

        Ok(ServerLock { file })
    }
}

impl Drop for ServerLock {
    fn drop(&mut self) {
        let _ = FileExt::unlock(&self.file);
    }
}
