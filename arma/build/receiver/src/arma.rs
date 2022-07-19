use crate::BuildResult;
use vfs::{PhysicalFS, VfsPath};

pub struct Arma {
    server_path: VfsPath,
}

impl Arma {
    pub fn new(server_path: &str) -> Self {
        Arma {
            server_path: VfsPath::new(PhysicalFS::new(server_path)),
        }
    }

    pub fn copy_mod(&self, build_path: &str) -> BuildResult {
        // Remove the mod completely
        let mod_path = self.server_path.join("@esm")?;
        mod_path.remove_dir_all()?;

        // Then copy the fresh one over
        let build_path = VfsPath::new(PhysicalFS::new("C:")).join(&build_path[1..])?;
        build_path.copy_dir(&mod_path)?;

        Ok(())
    }
}
