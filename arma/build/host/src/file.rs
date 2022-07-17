use crate::{server::Server, BuildResult, Command, FileChunk, FileTransfer};
use sha1::{Digest, Sha1};
use uuid::Uuid;
use vfs::VfsPath;

const CHUNK_SIZE: usize = 65536;

pub struct File {}
impl File {
    pub fn transfer(
        server: &mut Server,
        source_path: VfsPath,
        destination_path: VfsPath,
        file_name: &str,
    ) -> BuildResult {
        let source_path = source_path.join(&file_name)?;

        let mut bytes = Vec::new();
        source_path.open_file()?.read_to_end(&mut bytes)?;
        let total_size = bytes.len();
        let sha1 = Sha1::new().chain_update(&bytes).finalize().to_vec();

        let id = Uuid::new_v4();
        let transfer = FileTransfer {
            id,
            file_name: file_name.to_string(),
            destination_path: destination_path.as_str()[1..].to_string(),
            number_of_chunks: if total_size < CHUNK_SIZE {
                1
            } else {
                total_size / CHUNK_SIZE + 1
            },
            total_size,
            sha1,
        };

        if let Command::FileTransferResult(_b @ false) =
            server.send(Command::FileTransferStart(transfer))?
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

            server.send(chunk)?;
        }

        server.send(Command::FileTransferEnd(id))?;

        Ok(())
    }

    pub fn copy(source: &VfsPath, destination: &VfsPath) -> BuildResult {
        assert!(matches!(source.is_file(), Ok(f) if f));

        match source.copy_file(destination) {
            Ok(_) => Ok(()),
            Err(e) => Err(e.to_string().into()),
        }
    }
}
