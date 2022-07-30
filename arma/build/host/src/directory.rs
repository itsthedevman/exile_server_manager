use crate::{builder::Builder, BuildResult, File};
use common::System;

use vfs::VfsPath;
pub struct Directory;

impl Directory {
    pub fn transfer(builder: &mut Builder, source_path: VfsPath) -> BuildResult {
        let dir_name = source_path.filename();
        let file_name = format!("{}.zip", dir_name);
        let parent_path = source_path.parent().unwrap();

        File::transfer(builder, parent_path, &file_name)?;

        let destination_path = builder.remote_build_path_str();
        match builder.os {
            crate::BuildOS::Linux => todo!(),
            crate::BuildOS::Windows => {
                let script = format!(
                    r#"
                        Import-Module Microsoft.PowerShell.Archive;
                        Expand-Archive -Path "{destination_path}\{file_name}" -DestinationPath {destination_path};
                        Remove-Item -Path "{destination_path}\{file_name}";
                    "#
                );

                builder.system_command(System::new().command(script).wait())?;
            }
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
