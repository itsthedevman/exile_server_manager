use std::path::{Path, PathBuf};

use crate::{builder::Builder, BuildResult, File};
use common::System;

pub struct Directory;

impl Directory {
    pub fn transfer(
        builder: &mut Builder,
        source_path: PathBuf,
        destination_path: PathBuf,
    ) -> BuildResult {
        let dir_name = source_path.file_name().unwrap().to_string_lossy();
        let file_name = format!("{}.zip", dir_name);

        if crate::builder::local_command(
            &format!(
                "cd {}; zip -r {} ./{}",
                source_path.parent().unwrap().to_string_lossy(),
                builder.local_build_path.join(&file_name).to_string_lossy(),
                dir_name
            ),
            vec![],
        )
        .is_err()
        {
            return Err(format!(
                "Failed to zip {} for transfer",
                source_path.to_string_lossy()
            )
            .into());
        };

        File::transfer(
            builder,
            builder.local_build_path.to_owned(),
            destination_path,
            &file_name,
        )?;

        let destination_path = builder.remote_build_path_str();
        match builder.os {
            crate::BuildOS::Linux => todo!(),
            crate::BuildOS::Windows => {
                let script = format!(
                    r#"
                        Import-Module Microsoft.PowerShell.Archive;
                        Expand-Archive -Force -Path "{destination_path}\{file_name}" -DestinationPath {destination_path};
                        Remove-Item -Path "{destination_path}\{file_name}";
                    "#
                );

                builder.system_command(System::new().command(script).wait())?;
            }
        }
        Ok(())
    }

    pub fn copy(source: &Path, destination: &Path) -> BuildResult {
        assert!(matches!(source.is_dir(), true));

        crate::builder::local_command(
            "cp",
            vec![
                "-r",
                &source.to_string_lossy(),
                &destination.to_string_lossy(),
            ],
        )?;

        Ok(())
    }
}
