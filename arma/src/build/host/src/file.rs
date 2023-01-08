use sha1::{Digest, Sha1};
use std::path::{Path, PathBuf};
use uuid::Uuid;

use crate::*;

const CHUNK_SIZE: usize = 65536;

pub struct File {}
impl File {
    pub fn transfer(
        builder: &mut Builder,
        source_path: PathBuf,
        destination_path: PathBuf,
        file_name: &str,
    ) -> BuildResult {
        let source_path = source_path.join(file_name);

        let bytes = std::fs::read(source_path).unwrap();

        let total_size = bytes.len();
        let sha1 = Sha1::new().chain_update(&bytes).finalize().to_vec();

        let id = Uuid::new_v4();
        let transfer = FileTransfer {
            id,
            file_name: file_name.to_string(),
            destination_path: destination_path.to_string_lossy().to_string(),
            number_of_chunks: if total_size < CHUNK_SIZE {
                1
            } else {
                total_size / CHUNK_SIZE + 1
            },
            total_size,
            sha1,
        };

        if let Command::FileTransferResult(_b @ false) = builder
            .build_server
            .send(Command::FileTransferStart(transfer))?
        {
            return Ok(());
        }

        let chunks = bytes.chunks(CHUNK_SIZE);
        for (index, bytes) in chunks.enumerate() {
            let chunk = Command::FileTransferChunk(FileChunk {
                id,
                index,
                size: bytes.len(),
                bytes: bytes.to_vec(),
            });

            builder.build_server.send(chunk)?;
        }

        builder.build_server.send(Command::FileTransferEnd(id))?;

        Ok(())
    }

    pub fn copy(source: &Path, destination: &Path) -> BuildResult {
        assert!(source.is_file());

        std::fs::copy(source, destination)?;
        Ok(())
    }
}
