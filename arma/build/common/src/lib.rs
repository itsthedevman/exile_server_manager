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
    PostInitRequest,
    PostInit(PostInit),
    Error(String),
    System(System),
    SystemResponse(String),
    Database(String),
    FileTransferStart(FileTransfer),
    FileTransferResult(bool),
    FileTransferChunk(FileChunk),
    FileTransferEnd(Uuid),
    LogStreamInit,
    LogStreamRequest,
    LogStream(Vec<LogLine>),
}

impl Default for Command {
    fn default() -> Self {
        Command::Hello
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct System {
    pub command: String,
    pub arguments: Vec<String>,
    pub wait: bool,
    pub detections: Vec<Detection>,
    pub return_output: bool,
}

impl System {
    pub fn new() -> Self {
        System {
            command: "".into(),
            arguments: vec![],
            wait: false,
            detections: vec![],
            return_output: false,
        }
    }

    pub fn command<S: AsRef<str>>(&mut self, command: S) -> &mut Self {
        self.command = command.as_ref().to_string();
        self
    }

    pub fn arguments<S: AsRef<str>>(&mut self, arguments: Vec<S>) -> &mut Self {
        self.arguments = arguments.iter().map(|a| a.as_ref().to_string()).collect();
        self
    }

    pub fn wait(&mut self) -> &mut Self {
        self.wait = true;
        self
    }

    pub fn add_detection(&mut self, regex_str: &str, causes_error: bool) -> &mut Self {
        self.detections.push(Detection {
            regex: regex_str.to_string(),
            causes_error,
        });
        self
    }

    pub fn with_output(&mut self) -> &mut Self {
        self.wait();
        self.return_output = true;
        self
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Detection {
    pub regex: String,
    pub causes_error: bool,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct FileTransfer {
    pub id: Uuid,
    pub file_name: String,
    pub destination_path: String,
    pub sha1: Vec<u8>,
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

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct PostInit {
    pub build_path: String,
    pub server_path: String,
    pub server_args: String,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct LogLine {
    pub filename: String,
    pub color: [u8; 3],
    pub content: String,
    pub line_number: usize,
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
