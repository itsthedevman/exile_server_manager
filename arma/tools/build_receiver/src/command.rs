use std::process::Command as SystemCommand;
use std::time::Duration;

use crate::{read_lock, BuildResult, Command, System, client::Client};
use colored::Colorize;

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
        let result = SystemCommand::new(&command.cmd)
            .args(&command.args)
            .output();

        match result {
            Ok(output) => {
                if command.check_for_success {
                    let status = output.status;
                    let stdout = String::from_utf8_lossy(&output.stdout);
                    let stderr = String::from_utf8_lossy(&output.stderr);

                    if !status.success() {
                        return Err(stderr.to_string().into());
                    }

                    // let regex = match Regex::from_str(&command.success_regex) {
                    //     Ok(r) => r,
                    //     Err(e) => return Err(e.to_string().into()),
                    // };

                    println!("STDOUT: {}", stdout);
                    println!("STDERR: {}", stderr);
                }

                Ok(())
            }
            Err(e) => {
                println!("{}", format!("Failed! {e}").red());
                Err(e.to_string().into())
            }
        }
    }
}
