use std::io::{BufRead, BufReader};
use std::process::{Command as SystemCommand, Stdio};
use std::str::FromStr;
use std::time::Duration;

use crate::{client::Client, read_lock, BuildResult, Command, System};
use colored::Colorize;
use regex::Regex;

pub struct IncomingCommand;
impl IncomingCommand {
    pub fn execute(client: &Client, network_command: &Command) -> BuildResult {
        match network_command {
            Command::System(command) => IncomingCommand.system_command(command),
            Command::FileTransferStart(transfer) => read_lock(
                &client.transfers,
                Duration::from_secs_f32(0.1),
                |transfers| {
                    transfers.start_new(transfer)?;
                    Ok(true)
                },
            ),
            Command::FileTransferChunk(chunk) => read_lock(
                &client.transfers,
                Duration::from_secs_f32(0.1),
                |transfers| {
                    transfers.append_chunk(chunk)?;
                    Ok(true)
                },
            ),
            Command::FileTransferEnd(id) => read_lock(
                &client.transfers,
                Duration::from_secs_f32(0.1),
                |transfers| {
                    transfers.complete(id)?;
                    Ok(true)
                },
            ),
            _ => Ok(()),
        }
    }

    fn system_command(&self, command: &System) -> BuildResult {
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

        Ok(())
    }
}
