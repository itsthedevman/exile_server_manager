use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub mod error;

#[derive(Serialize, Deserialize)]
pub enum NetworkCommands {
    Hello,
    Success,
    Error(String),
    SystemCommand(String, Vec<String>),
    FileTransferStart(FileTransfer),
    FileTransferChunk(FileChunk),
    FileTransferEnd(Uuid),
}

#[derive(Serialize, Deserialize)]
pub struct FileTransfer {
    pub id: Uuid,
    pub file_name: String,
    pub destination_path: String,
    pub total_size: usize,
}

#[derive(Serialize, Deserialize)]
pub struct FileChunk {
    pub id: Uuid,
    pub size: usize,
    pub bytes: Vec<u8>,
}
