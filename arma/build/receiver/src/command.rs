use std::io::{BufRead, BufReader};
use std::process::{Command as SystemCommand, Stdio};
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::{client::Client, read_lock, BuildError, Command, System};
use colored::Colorize;
use common::{write_lock, LogLine, PostInit};
use lazy_static::lazy_static;
use parking_lot::RwLock;
use regex::Regex;

pub struct IncomingCommand;
impl IncomingCommand {
    pub fn execute(client: &Client, network_command: &Command) -> Result<Command, BuildError> {
        match network_command {
            Command::PostInitRequest => Ok(Command::PostInit(PostInit {
                build_path: client.arma.build_path.to_owned(),
                server_path: client.arma.server_path.to_owned(),
                server_args: client.arma.server_args.to_owned(),
            })),
            Command::KillArma => IncomingCommand::kill_arma(),
            Command::System(command) => IncomingCommand::system_command(command),
            Command::FileTransferStart(transfer) => {
                let result = AtomicBool::new(false);
                read_lock(&client.transfers, |transfers| {
                    result.store(transfers.start_new(transfer)?, Ordering::SeqCst);
                    Ok(true)
                })?;

                Ok(Command::FileTransferResult(result.load(Ordering::SeqCst)))
            }
            Command::FileTransferChunk(chunk) => {
                read_lock(&client.transfers, |transfers| {
                    transfers.append_chunk(chunk)?;
                    Ok(true)
                })?;

                Ok(Command::Success)
            }
            Command::FileTransferEnd(id) => {
                read_lock(&client.transfers, |transfers| {
                    transfers.complete(id)?;
                    Ok(true)
                })?;

                Ok(Command::Success)
            }
            Command::Database(query) => {
                client.database.exec_query(query)?;
                Ok(Command::Success)
            }
            Command::LogStreamInit => {
                write_lock(&client.log, |mut log| {
                    log.reset()?;
                    Ok(true)
                })?;

                Ok(Command::Success)
            }
            Command::LogStreamRequest => {
                let result: RwLock<Option<Vec<LogLine>>> = RwLock::new(None);

                write_lock(&client.log, |mut log| {
                    *result.write() = Some(log.read_lines());
                    Ok(true)
                })?;

                let mut writer = result.write();
                Ok(Command::LogStream(writer.take().unwrap()))
            }
            _ => Ok(Command::Error("Command not implemented yet".into())),
        }
    }

    pub fn kill_arma() -> Result<Command, BuildError> {
        lazy_static! {
            // Stop-Process doesn't want the extension
            static ref WINDOWS_EXES: &'static [&'static str] = &[
                "arma3server",
                "arma3server_x64",
                "arma3_x64",
                "arma3",
                "arma3battleye"
            ];
            static ref LINUX_EXES: &'static [&'static str] = &["arma3server", "arma3server_x64"];
        };

        let (command, args) = if cfg!(windows) {
            (
                "powershell",
                WINDOWS_EXES
                    .iter()
                    .map(|exe| format!("Get-Process -Name \"{exe}\" -ErrorAction SilentlyContinue | Stop-Process -Force"))
                    .collect::<Vec<String>>(),
            )
        } else {
            (
                "eval",
                LINUX_EXES
                    .iter()
                    .map(|exe| format!("pkill \"{exe}\""))
                    .collect::<Vec<String>>(),
            )
        };

        let output = SystemCommand::new(&command)
            .args(&vec![args.join(";")])
            .output()?;

        Ok(Command::Success)
    }

    pub fn system_command(command: &System) -> Result<Command, BuildError> {
        println!(
            "\n{} {}\n",
            command.command.bright_blue(),
            command.arguments.join(" ").black()
        );

        let mut child = SystemCommand::new(&command.command)
            .args(&command.arguments)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        if !command.wait {
            return Ok(Command::SystemResponse(String::new()));
        };

        let mut output = String::new();
        if let Some(stderr) = child.stderr.take() {
            let reader = BufReader::new(stderr);
            for line in reader.lines() {
                let line = line.unwrap();
                output.push_str(&format!("{}\n", line));

                println!("{} - {}", "stderr".bright_red(), line);
            }
        }

        if let Some(stdout) = child.stdout.take() {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                let line = line.unwrap();
                output.push_str(&format!("{}\n", line));

                println!("{} - {}", "stdout".bright_cyan(), line);
            }
        }

        let mut result = String::new();
        for detection in command.detections.iter() {
            let regex = match Regex::from_str(&detection.regex) {
                Ok(r) => r,
                Err(e) => return Err(e.to_string().into()),
            };

            let matches = match regex.captures(&output) {
                Some(m) => m,
                None => continue,
            };

            if detection.causes_error {
                return Err(output.into());
            }

            result.push_str(matches.get(0).unwrap().as_str());
        }

        if command.return_output {
            result.push_str(&output);
        }

        Ok(Command::SystemResponse(result))
    }
}
