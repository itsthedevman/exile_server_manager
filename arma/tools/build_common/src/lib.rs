use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub mod error;
pub use error::*;

#[derive(Serialize, Deserialize, Debug)]
pub enum NetworkCommands {
    Hello,
    Success,
    Error(String),
    SystemCommand(String, Vec<String>),
    FileTransferStart(FileTransfer),
    FileTransferChunk(FileChunk),
    FileTransferEnd(Uuid),
}

#[derive(Serialize, Deserialize, Debug)]
pub struct FileTransfer {
    pub id: Uuid,
    pub file_name: String,
    pub destination_path: String,
    pub number_of_chunks: usize,
    pub total_size: usize,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct FileChunk {
    pub id: Uuid,
    pub index: usize,
    pub size: usize,
    pub bytes: Vec<u8>,
}

pub type BuildResult = Result<(), BuildError>;
