use crate::server::{NetworkCommands, Server};
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use vfs::{PhysicalFS, SeekAndRead, VfsPath};

const CHUNK_SIZE: usize = 65536;

#[derive(Serialize, Deserialize)]
pub struct Transfer {
    id: Uuid,
    file_name: String,
    destination_path: String,
    total_size: usize,
}

#[derive(Serialize, Deserialize)]
pub struct FileChunk {
    id: Uuid,
    size: usize,
    bytes: Vec<u8>,
}

impl Transfer {
    pub fn file(
        server: &Server,
        source_path: &str,
        file_name: &str,
        destination_path: &str,
    ) -> crate::builder::BuildResult {
        let path = VfsPath::new(PhysicalFS::new(source_path))
            .join(file_name)
            .unwrap();

        let total_size = match path.metadata() {
            Ok(m) => m.len as usize,
            Err(e) => {
                return Err(format!(
                    "Failed to read metadata for file {}. {}",
                    path.filename(),
                    e
                ))
            }
        };

        let id = Uuid::new_v4();
        let transfer = Transfer {
            id,
            file_name: file_name.to_string(),
            destination_path: destination_path.to_string(),
            total_size,
        };

        server.send(NetworkCommands::FileTransferStart(transfer));

        let mut file = match path.open_file() {
            Ok(f) => f,
            Err(e) => {
                return Err(format!(
                    "Failed to file for reading {}. {}",
                    path.filename(),
                    e
                ))
            }
        };

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
}

fn chunk_file(file: &mut Box<dyn SeekAndRead>) -> Option<Vec<u8>> {
    let mut data = [0; CHUNK_SIZE];

    let bytes_read = file.read(&mut data).unwrap();
    if bytes_read == 0 {
        return None;
    }

    Some(Vec::from(&data[0..bytes_read]))
}
