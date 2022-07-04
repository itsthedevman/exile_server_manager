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
    System(System),
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
pub struct System {
    pub cmd: String,
    pub args: Vec<String>,
    pub check_for_success: bool,
    pub success_regex: String,
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

pub fn read_lock<T, F>(lock: &RwLock<T>, code: F) -> BuildResult
where
    F: Fn(RwLockReadGuard<T>) -> Result<bool, BuildError>,
{
    loop {
        let reader = match lock.try_read() {
            Some(r) => r,
            None => {
                continue;
            }
        };

        match code(reader) {
            Ok(exit_loop) => {
                if exit_loop {
                    break;
                }
            }
            Err(e) => return Err(e),
        }
    }

    Ok(())
}

pub fn write_lock<T, F>(lock: &RwLock<T>, code: F) -> BuildResult
where
    F: Fn(RwLockWriteGuard<T>) -> Result<bool, BuildError>,
{
    loop {
        let writer = match lock.try_write() {
            Some(w) => w,
            None => {
                continue;
            }
        };

        match code(writer) {
            Ok(exit_loop) => {
                if exit_loop {
                    break;
                }
            }
            Err(e) => return Err(e),
        }
    }

    Ok(())
}
