use colored::*;
use parking_lot::{RwLock, RwLockReadGuard, RwLockWriteGuard};
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::{
    io::{BufRead, BufReader},
    process::{Command as SystemCommand, Stdio},
    str::FromStr,
    sync::mpsc::channel,
};
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
    KillArma,
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
    Key(String),
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
    pub detections: Vec<Detection>,
    pub forget: bool,
    pub print_stdout: bool,
    pub print_stderr: bool,
    pub print_as: String,
}

impl System {
    pub fn new() -> Self {
        System {
            command: "".into(),
            arguments: vec![],
            detections: vec![],
            forget: false,
            print_stdout: false,
            print_stderr: false,
            print_as: "".into(),
        }
    }

    pub fn command<S: AsRef<str>>(&mut self, command: S) -> &mut Self {
        self.command = command.as_ref().to_string();
        self
    }

    pub fn script<S: AsRef<str>>(&mut self, script: S) -> &mut Self {
        self.arguments.clear();

        if cfg!(windows) {
            self.command("powershell");
        } else {
            self.command("bash");
            self.arguments(&["-c", script.as_ref()]);
        }

        self
    }

    pub fn arguments<S: AsRef<str>>(&mut self, arguments: &[S]) -> &mut Self {
        self.arguments = arguments.iter().map(|a| a.as_ref().to_string()).collect();
        self
    }

    pub fn add_detection(&mut self, regex_str: &str) -> &mut Self {
        self.detections.push(Detection {
            regex: regex_str.to_string(),
            causes_error: false,
        });
        self
    }

    pub fn add_error_detection(&mut self, regex_str: &str) -> &mut Self {
        self.detections.push(Detection {
            regex: regex_str.to_string(),
            causes_error: true,
        });
        self
    }

    pub fn print_stderr(&mut self) -> &mut Self {
        self.print_stderr = true;
        self
    }

    pub fn print_stdout(&mut self) -> &mut Self {
        self.print_stdout = true;
        self
    }

    pub fn print(&mut self) -> &mut Self {
        self.print_stderr();
        self.print_stdout();
        self
    }

    pub fn print_as(&mut self, name: &str) -> &mut Self {
        self.print_as = name.to_string();
        self
    }

    /// Sets the command to be ran in the background, which ignores the output/errors of the command
    pub fn forget(&mut self) -> &mut Self {
        self.forget = true;
        self
    }

    pub fn command_string(&self) -> String {
        format!("{} {}", self.command, self.arguments.join(" "))
    }

    pub fn execute(&self) -> Result<String, BuildError> {
        let mut child = SystemCommand::new(&self.command)
            .args(&self.arguments)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        if self.forget {
            return Ok(String::new());
        };

        let (sender, receiver) = channel::<(&str, String)>();

        let stdout_sender = sender.clone();
        let stdout = child.stdout.take();
        let stdout_handle = std::thread::spawn(move || {
            if let Some(stdout) = stdout {
                let reader = BufReader::new(stdout);
                for line in reader.lines() {
                    let Ok(line) = line else {
                        continue;
                    };

                    if let Err(_e) = stdout_sender.send(("stdout", line)) {
                        continue;
                    }
                }
            }
        });

        let stderr_sender = sender.clone();
        let stderr = child.stderr.take();
        let stderr_handle = std::thread::spawn(move || {
            if let Some(stderr) = stderr {
                let reader = BufReader::new(stderr);
                for line in reader.lines() {
                    let Ok(line) = line else {
                        continue;
                    };

                    if let Err(_e) = stderr_sender.send(("stderr", line)) {
                        continue;
                    }
                }
            }
        });

        drop(sender);

        // Formatting
        if self.print_stdout || self.print_stderr {
            println!();
        }

        let mut stdout_output = String::new();
        let mut stderr_output = String::new();
        let print_as = if self.print_as.is_empty() {
            &self.command
        } else {
            &self.print_as
        };

        while let Ok((name, line)) = receiver.recv() {
            match name {
                "stdout" => {
                    stdout_output.push_str(&format!("{line}\n"));

                    if self.print_stdout {
                        println!(
                            "{} - {} -> {}",
                            "<esm_bt>".blue().bold(),
                            print_as,
                            line.trim().black()
                        );
                    }
                }
                "stderr" => {
                    stderr_output.push_str(&format!("{line}\n"));

                    if self.print_stderr {
                        println!(
                            "{} - {} -> {}",
                            "<esm_bt>".blue().bold(),
                            print_as,
                            line.trim().black()
                        );
                    }
                }
                _ => {}
            };
        }

        // println!(
        //     "\n{}\n    OUT: {:?}\n    ERR: {:?}",
        //     self.command_string(),
        //     stdout_output,
        //     stderr_output
        // );

        let status = child.wait()?;

        if let Err(e) = stdout_handle.join() {
            return Err(format!("{e:?}").into());
        }

        if let Err(e) = stderr_handle.join() {
            return Err(format!("{e:?}").into());
        }

        if !status.success() {
            return Err(format!("Execution failed with exit code {:?}", status.code()).into());
        }

        let stdout_output = stdout_output.trim().to_string();
        let stderr_output = stderr_output.trim().to_string();

        if self.detections.is_empty() {
            return Ok(stdout_output);
        }

        let command_results = format!("{} {}", stdout_output, stderr_output);
        let mut detection_results = String::new();

        for detection in self.detections.iter() {
            let regex = match Regex::from_str(&format!("(?i){}", detection.regex)) {
                Ok(r) => r,
                Err(e) => return Err(e.to_string().into()),
            };

            let matches = match regex.captures(&command_results) {
                Some(m) => m,
                None => continue,
            };

            let Some(m) = matches.get(0) else {
                continue;
            };

            if detection.causes_error {
                return Err(command_results.into());
            }

            detection_results.push_str(m.as_str());
        }

        if detection_results.is_empty() {
            Ok(stdout_output)
        } else {
            Ok(detection_results)
        }
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
