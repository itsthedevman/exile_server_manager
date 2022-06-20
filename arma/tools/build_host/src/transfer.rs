use crate::{builder::BuildResult, server::Server, FileTransfer, NetworkCommands, FileChunk};
use uuid::Uuid;
use vfs::{SeekAndRead, VfsPath};

const CHUNK_SIZE: usize = 65536;

pub struct Transfer;

impl Transfer {
    pub fn file(
        server: &Server,
        source_path: &VfsPath,
        destination_path: &VfsPath,
    ) -> crate::builder::BuildResult {
        // let source_file_path = source_path.join(file_name)?;
        let total_size = source_path.metadata()?.len as usize;

        let id = Uuid::new_v4();
        let transfer = FileTransfer {
            id,
            file_name: source_path.filename(),
            destination_path: destination_path.as_str().to_string(),
            total_size,
        };

        server.send(NetworkCommands::FileTransferStart(transfer));

        let mut file = source_path.open_file()?;
        while let Some(bytes) = chunk_file(&mut file) {
            server.send(NetworkCommands::FileTransferChunk(FileChunk {
                id,
                size: bytes.len(),
                bytes,
            }));
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

            let relative_path = path.as_str().replace(path.root().as_str(), "");
            Transfer::file(server, &path, &destination_path.join(&relative_path[1..])?)?;
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
