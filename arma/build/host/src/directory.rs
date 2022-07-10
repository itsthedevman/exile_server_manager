use crate::{server::Server, BuildResult, File};
use vfs::VfsPath;

pub struct Directory;

impl Directory {
    pub fn transfer(
        server: &mut Server,
        source_path: VfsPath,
        destination_path: VfsPath,
    ) -> BuildResult {
        let file_paths: Vec<VfsPath> = source_path
            .walk_dir()?
            .filter(|p| match p {
                Ok(p) => p.is_file().unwrap(),
                Err(_e) => false,
            })
            .map(|p| p.unwrap())
            .collect();

        for path in file_paths {
            let parent_path = source_path.parent().unwrap().as_str().to_owned();
            let mut server = server.to_owned();
            let destination_path = destination_path.clone();

            let relative_path = path.as_str().replace(&parent_path, "");
            let file_name = path.filename();

            File::transfer(
                &mut server,
                path.parent().unwrap(),
                destination_path
                    .join(&relative_path[1..])?
                    .parent()
                    .unwrap(),
                &file_name,
            )
            .unwrap();
        }

        Ok(())
    }

    pub fn copy(source: &VfsPath, destination: &VfsPath) -> BuildResult {
        assert!(matches!(source.is_dir(), Ok(d) if d));

        match source.copy_dir(destination) {
            Ok(_) => Ok(()),
            Err(e) => Err(e.to_string().into()),
        }
    }
}
