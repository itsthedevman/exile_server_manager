use crate::{server::Server, BuildResult, FileChunk, FileTransfer, NetworkCommands};
use uuid::Uuid;
use vfs::{SeekAndRead, VfsPath};

const CHUNK_SIZE: usize = 65536;

pub struct Transfer;

impl Transfer {
    pub fn file(
        server: &Server,
        source_path: &VfsPath,
        destination_path: &VfsPath,
        file_name: String,
    ) -> BuildResult {
        let total_size = source_path.metadata()?.len as usize;

        let id = Uuid::new_v4();
        let transfer = FileTransfer {
            id,
            file_name,
            destination_path: destination_path.as_str()[1..].to_string(),
            number_of_chunks: if total_size < CHUNK_SIZE {
                1
            } else {
                total_size / CHUNK_SIZE
            },
            total_size,
        };

        server.send(NetworkCommands::FileTransferStart(transfer));

        let mut file = source_path.open_file()?;
        let mut index = 0;
        while let Some(bytes) = chunk_file(&mut file) {
            server.send(NetworkCommands::FileTransferChunk(FileChunk {
                id,
                index,
                size: bytes.len(),
                bytes,
            }));

            index += 1;
        }

        server.send(NetworkCommands::FileTransferEnd(id));

        Ok(())
    }

    pub fn directory(
        server: &Server,
        source_path: &VfsPath,
        destination_path: &VfsPath,
    ) -> BuildResult {
        for path in source_path.walk_dir()? {
            let path = path?;
            if path.is_dir()? {
                continue;
            }

            // This removes the source_path's... path... from the file's path.
            // This keeps the same structure of the file so it can be copied wherever on the remote
            let relative_path = path
                .as_str()
                .replace(source_path.parent().unwrap().as_str(), "");

            Transfer::file(
                server,
                &path,
                &destination_path
                    .join(&relative_path[1..])?
                    .parent()
                    .unwrap(),
                path.filename(),
            )?;
        }

        Ok(())
    }
}

fn chunk_file(file: &mut Box<dyn SeekAndRead>) -> Option<Vec<u8>> {
    let mut data = [0; CHUNK_SIZE];

    let bytes_read = file.read(&mut data).unwrap();
    if bytes_read == 0 {
        return None;
    }

    Some(Vec::from(&data[0..bytes_read]))
}
