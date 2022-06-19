use std::collections::HashMap;

use lazy_static::lazy_static;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use vfs::{PhysicalFS, VfsPath};

use crate::client::BuildResult;

lazy_static! {
    static ref TRANSFERS: RwLock<HashMap<Uuid, FileTransfer>> = RwLock::new(HashMap::new());
}

#[derive(Serialize, Deserialize)]
pub struct Transfer {
    pub id: Uuid,
    pub file_name: String,
    pub destination_path: String,
    pub total_size: usize,
}

#[derive(Serialize, Deserialize)]
pub struct FileChunk {
    id: Uuid,
    size: usize,
    bytes: Vec<u8>,
}

struct FileTransfer {
    pub size: usize,
    pub total_size: usize,
    pub path: VfsPath,
}

impl Transfer {
    pub fn start(transfer: &Transfer) -> BuildResult {
        let transfers = TRANSFERS.read();
        if transfers.contains_key(&transfer.id) {
            return Err(format!(
                "Transfer with ID {} has already been started",
                transfer.id
            ));
        }

        let path = VfsPath::new(PhysicalFS::new(&transfer.destination_path))
            .join(&transfer.file_name)
            .unwrap();

        match path.create_file() {
            Ok(_f) => {}
            Err(e) => return Err(format!("Failed to start file transfer. {}", e)),
        }

        let file_transfer = FileTransfer {
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
            None => return Err(format!("Unexpected chunk for transfer {}", chunk.id)),
        };

        let write_size = match transfer.path.append_file() {
            Ok(mut f) => match f.write(&chunk.bytes) {
                Ok(r) => r,
                Err(e) => return Err(format!("Failed to write chunk to file {}. {}", chunk.id, e)),
            },
            Err(e) => {
                return Err(format!(
                    "Failed to open file for writing {}. {}",
                    chunk.id, e
                ))
            }
        };

        if write_size != chunk.size as usize {
            return Err(format!(
                "Written bytes does not match provided bytes for {}",
                chunk.id
            ));
        }

        transfer.size += write_size;

        Ok(())
    }

    pub fn end(id: &Uuid) -> BuildResult {
        let mut transfers = TRANSFERS.write();

        let transfer = match transfers.remove(id) {
            Some(t) => t,
            None => return Err(format!("Transfer has already been completed for {}", id)),
        };

        if transfer.size != transfer.total_size {
            return Err(format!(
                "Transfer was completed before all bytes were written for {}",
                id
            ));
        }

        Ok(())
    }
}
