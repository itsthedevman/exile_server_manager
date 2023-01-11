use colored::*;
use lazy_static::lazy_static;
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

lazy_static! {
    pub static ref WHITESPACE_REGEX: Regex = Regex::new(r"\t|\s+").unwrap();
    pub static ref HIGHLIGHTS: Vec<Highlight> = vec![
        Highlight {
            regex: Regex::new(r"ERROR\b").unwrap(),
            color: [153, 0, 51],
        },
        Highlight {
            regex: Regex::new(r"WARN").unwrap(),
            color: [153, 102, 0],
        },
        Highlight {
            regex: Regex::new(r"INFO").unwrap(),
            color: [102, 204, 255],
        },
        Highlight {
            regex: Regex::new(r"DEBUG").unwrap(),
            color: [80, 82, 86],
        },
        Highlight {
            regex: Regex::new(r"TRACE").unwrap(),
            color: [255, 153, 102],
        },
    ];
}

pub struct Highlight {
    pub regex: Regex,
    pub color: [u8; 3],
}

pub trait NetworkSend {
    fn send(&self, command: Command) -> Result<Command, BuildError>;
}

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
    Print(String),
}

impl Default for Command {
    fn default() -> Self {
        Command::Hello
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, Default)]
pub struct System {
    pub command: String,
    pub script: String,
    pub arguments: Vec<String>,
    pub detections: Vec<Detection>,
    pub forget: bool,
    pub print_stdout: bool,
    pub print_stderr: bool,
    pub print_as: String,
    pub target_os: String,
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
            target_os: "linux".into(),
            script: "".into(),
        }
    }

    pub fn windows(&mut self) -> &mut Self {
        self.target_os = "windows".into();
        self
    }

    pub fn linux(&mut self) -> &mut Self {
        self.target_os = "linux".into();
        self
    }

    pub fn command<S: AsRef<str>>(&mut self, command: S) -> &mut Self {
        self.command = command.as_ref().to_string();
        self
    }

    pub fn script<S: AsRef<str> + std::fmt::Display>(&mut self, script: S) -> &mut Self {
        self.script = WHITESPACE_REGEX
            .replace_all(script.as_ref(), " ")
            .to_string();
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

    pub fn execute(&mut self) -> Result<String, BuildError> {
        // println!("\nRunning \"{}\"", self.command_string());

        // TODO: This does not support running scripts when executing from Windows.
        // This isn't really an issue right now since the host is being ran from linux
        if !self.script.is_empty() {
            self.command("bash");

            self.arguments.clear();
            self.arguments(&["-c", self.script.to_string().as_ref()]);
        }

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

        let mut stdout_output = Vec::new();
        let mut stderr_output = Vec::new();
        let print_as = if self.print_as.is_empty() {
            &self.command
        } else {
            &self.print_as
        };

        while let Ok((name, line)) = receiver.recv() {
            match name {
                "stdout" => {
                    if self.print_stdout {
                        print!(
                            "\n{} - {} -> {}",
                            "<esm_bt>".blue().bold(),
                            print_as.bold().underline(),
                            line.trim().black()
                        );
                    }

                    stdout_output.push(line);
                }
                "stderr" => {
                    if self.print_stderr {
                        print!(
                            "\n{} - {} -> {}",
                            "<esm_bt>".blue().bold(),
                            print_as.bold().underline(),
                            line.trim().black()
                        );
                    }

                    stderr_output.push(line);
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

        // Ensures everything prints and gets the final newline after a possible print above
        if (self.print_stdout && !stdout_output.is_empty())
            || (self.print_stderr && !stderr_output.is_empty())
        {
            println!();
        }

        if !status.success() {
            let line_prefix = format!(
                "{} - {} ->",
                "<esm_bt>".blue().bold(),
                print_as.red().bold()
            );

            if !stdout_output.is_empty() {
                for line in stdout_output {
                    println!("{line_prefix} {}", line);
                }
            }

            if !stderr_output.is_empty() {
                for line in stderr_output {
                    println!("{line_prefix} {}", line);
                }
            }

            return Err(format!(
                "Execution for command failed with exit code {:?}\n{}",
                status.code(),
                self.command_string().red()
            )
            .into());
        }

        let stdout_output = stdout_output.join("\n");
        let stderr_output = stderr_output.join("\n");

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

    pub fn execute_remote(&mut self, endpoint: &dyn NetworkSend) -> Result<String, BuildError> {
        // Using System to execute a script for windows ON windows is not supported by this code
        // It assumes this is being build on linux and then sent to windows
        if self.target_os == "windows" {
            let mut script = &self.command_string();

            if !self.script.is_empty() {
                script = &self.script;
            }

            // Removes the "Preparing modules for first use." errors that powershell return
            let powershell_script = format!("$ProgressPreference = 'SilentlyContinue'; {}", script);

            // Convert the command file into UTF-16LE as required by Microsoft and then to base64 for transport
            let script = format!(
                "echo \"{}\" | iconv -t UTF-16LE | base64",
                powershell_script
            );

            if let Ok(encoded_script) = System::new().script(script).execute() {
                self.command("powershell");
                self.arguments(&["-EncodedCommand", encoded_script.as_ref()]);
            }
        }

        let result = endpoint.send(Command::System(self.to_owned()))?;

        let Command::SystemResponse(result) = result else {
            return Err("Invalid response for System command. Must be Command::SystemResponse".to_string().into());
        };

        Ok(result)
    }

    // fn remote_print(&self, content: &str, endpoint: &dyn NetworkSend) {
    //     if let Err(e) = endpoint.send(Command::Print(content.to_string())) {
    //         println!(
    //             "{} - {} - {e}",
    //             "<esm_bt>".blue().bold(),
    //             "failed to remote print".red()
    //         );
    //     }
    // }
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
