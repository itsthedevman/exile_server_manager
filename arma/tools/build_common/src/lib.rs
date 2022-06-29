use std::time::Duration;

use parking_lot::{RwLock, RwLockReadGuard, RwLockWriteGuard};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

pub mod error;
pub use error::*;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct NetworkCommand {
    pub id: Uuid,
    pub command: Command,
}

impl NetworkCommand {
    pub fn new(command: Command) -> Self {
        NetworkCommand {
            id: Uuid::new_v4(),
            command,
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub enum Command {
    Hello,
    Success,
    Error(String),
    System(String, Vec<String>),
    FileTransferStart(FileTransfer),
    FileTransferChunk(FileChunk),
    FileTransferEnd(Uuid),
}

impl Default for Command {
    fn default() -> Self {
        Command::Hello
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileTransfer {
    pub id: Uuid,
    pub file_name: String,
    pub destination_path: String,
    pub number_of_chunks: usize,
    pub total_size: usize,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileChunk {
    pub id: Uuid,
    pub index: usize,
    pub size: usize,
    pub bytes: Vec<u8>,
}

pub type BuildResult = Result<(), BuildError>;

pub fn read_lock<T, F>(lock: &RwLock<T>, wait: Duration, code: F)
where
    F: Fn(RwLockReadGuard<T>) -> bool,
{
    loop {
        let reader = match lock.try_read() {
            Some(r) => r,
            None => {
                std::thread::sleep(wait);
                continue;
            }
        };

        if code(reader) {
            break;
        }

        std::thread::sleep(wait);
    }
}

pub fn write_lock<T, F>(lock: &RwLock<T>, wait: Duration, code: F)
where
    F: Fn(RwLockWriteGuard<T>) -> bool,
{
    loop {
        let writer = match lock.try_write() {
            Some(w) => w,
            None => {
                std::thread::sleep(wait);
                continue;
            }
        };

        if code(writer) {
            break;
        }

        std::thread::sleep(wait);
    }
}
