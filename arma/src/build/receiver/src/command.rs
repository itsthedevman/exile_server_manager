use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

use crate::{client::Client, read_lock, BuildError, Command, System};
use colored::Colorize;
use common::{write_lock, LogLine, PostInit};
use lazy_static::lazy_static;
use parking_lot::RwLock;

pub struct IncomingCommand;
impl IncomingCommand {
    pub fn execute(client: &Client, network_command: &mut Command) -> Result<Command, BuildError> {
        println!("Executing {network_command:?}");

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
            Command::Key(key) => {
                // Build path
                let file_path = PathBuf::from(&client.arma.build_path)
                    .join("@esm")
                    .join("esm.key");

                std::fs::write(file_path.as_path(), key.as_bytes())?;

                // Server path
                let file_path = PathBuf::from(&client.arma.server_path)
                    .join("@esm")
                    .join("esm.key");

                std::fs::write(file_path.as_path(), key.as_bytes())?;

                // Reload key
                let reload_path = PathBuf::from(&client.arma.server_path)
                    .join("@esm")
                    .join(".RELOAD");

                std::fs::write(reload_path.as_path(), "true")?;

                println!(
                    "[key] Wrote {} and {}",
                    file_path.display(),
                    reload_path.display()
                );

                Ok(Command::Success)
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
            static ref LINUX_EXES: &'static [&'static str] = &["/arma3server/arma3server", "/arma3server/arma3server_x64"];
        };

        if cfg!(windows) {
            System::new()
                    .command("powershell")
                    .arguments(&WINDOWS_EXES
                        .iter()
                        .map(|exe| format!("Get-Process -Name \"{exe}\" -ErrorAction SilentlyContinue | Stop-Process -Force"))
                        .collect::<Vec<String>>())
                    .execute()?;
        } else {
            System::new()
                .command("/bin/bash")
                .arguments(&[
                    "-c",
                    &format!(
                        "for pid in $(ps -ef | awk '/{}/ {{print $2}}'); do kill -9 $pid; done",
                        LINUX_EXES.join("|")
                    ),
                ])
                .execute()?;
        }

        Ok(Command::Success)
    }

    pub fn system_command(command: &mut System) -> Result<Command, BuildError> {
        println!(
            "\n{} {}\n",
            command.command.bright_blue(),
            command.arguments.join(" ").black()
        );

        let result = command.execute()?;
        Ok(Command::SystemResponse(result))
    }
}
