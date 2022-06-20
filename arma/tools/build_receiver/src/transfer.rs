use std::collections::HashMap;

use lazy_static::lazy_static;
use parking_lot::RwLock;
use uuid::Uuid;
use vfs::{PhysicalFS, VfsPath};

use crate::{BuildError, BuildResult, FileChunk, FileTransfer};

lazy_static! {
    static ref TRANSFERS: RwLock<HashMap<Uuid, IncomingTransfer>> = RwLock::new(HashMap::new());
    static ref ROOT_PATH: VfsPath = VfsPath::new(PhysicalFS::new("C:"));
}

struct IncomingTransfer {
    pub size: usize,
    pub total_size: usize,
    pub path: VfsPath,
}

pub struct Transfer;

impl Transfer {
    pub fn start(transfer: &FileTransfer) -> BuildResult {
        println!("Starting transfer");
        let transfers = TRANSFERS.read();
        if transfers.contains_key(&transfer.id) {
            return Err(BuildError::Generic(format!(
                "Transfer with ID {} has already been started",
                transfer.id
            )));
        }

        // Any slashes in the front will cause this to fail
        let destination_path =
            ROOT_PATH.join(&transfer.destination_path.trim_start_matches('/'))?;

        // Ensure all directories exist
        destination_path.create_dir_all()?;

        let path = destination_path.join(&transfer.file_name)?;
        path.create_file()?;

        let file_transfer = IncomingTransfer {
            size: 0,
            total_size: transfer.total_size,
            path,
        };

        drop(transfers);
        TRANSFERS.write().insert(transfer.id, file_transfer);

        Ok(())
    }

    pub fn append_chunk(chunk: &FileChunk) -> BuildResult {
        let mut transfers = TRANSFERS.write();

        let mut transfer = match transfers.get_mut(&chunk.id) {
            Some(t) => t,
            None => {
                return Err(BuildError::Generic(format!(
                    "Unexpected chunk for transfer {}",
                    chunk.id
                )))
            }
        };

        let write_size = transfer.path.append_file()?.write(&chunk.bytes)?;
        if write_size != chunk.size as usize {
            return Err(BuildError::Generic(format!(
                "Written bytes does not match provided bytes for {}",
                chunk.id
            )));
        }

        transfer.size += write_size;

        Ok(())
    }

    pub fn end(id: &Uuid) -> BuildResult {
        let mut transfers = TRANSFERS.write();

        let transfer = match transfers.remove(id) {
            Some(t) => t,
            None => {
                return Err(BuildError::Generic(format!(
                    "Transfer has already been completed for {}",
                    id
                )))
            }
        };

        if transfer.size != transfer.total_size {
            return Err(BuildError::Generic(format!(
                "Transfer was completed before all bytes were written for {}",
                id
            )));
        }

        Ok(())
    }
}
