use std::io::{BufRead, BufReader};
use std::process::{Command as SystemCommand, Stdio};
use std::str::FromStr;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::{client::Client, read_lock, BuildError, Command, System};
use colored::Colorize;
use regex::Regex;

pub struct IncomingCommand;
impl IncomingCommand {
    pub fn execute(client: &Client, network_command: &Command) -> Result<Command, BuildError> {
        match network_command {
            Command::System(command) => IncomingCommand.system_command(command),
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
            _ => Ok(Command::Error("Command not implemented yet".into())),
        }
    }

    fn system_command(&self, command: &System) -> Result<Command, BuildError> {
        println!(
            "\n{} {}\n",
            command.cmd.bright_blue(),
            command.args.join(" ").black()
        );

        let mut child = SystemCommand::new(&command.cmd)
            .args(&command.args)
            .stdout(Stdio::piped())
            .stderr(Stdio::piped())
            .spawn()?;

        let mut buffer = String::new();
        if let Some(stderr) = child.stderr.take() {
            let reader = BufReader::new(stderr);
            for line in reader.lines() {
                let line = line.unwrap();
                buffer.push_str(&format!("{}\n", line));

                println!("{} - {}", "stderr".bright_red(), line);
            }
        }

        if let Some(stdout) = child.stdout.take() {
            let reader = BufReader::new(stdout);
            for line in reader.lines() {
                let line = line.unwrap();
                buffer.push_str(&format!("{}\n", line));

                println!("{} - {}", "stdout".bright_cyan(), line);
            }
        }

        if command.check_for_success {
            let regex = match Regex::from_str(&command.success_regex) {
                Ok(r) => r,
                Err(e) => return Err(e.to_string().into()),
            };

            if !regex.is_match(&buffer) {
                return Err(buffer.into());
            }
        }

        Ok(Command::Success)
    }
}
