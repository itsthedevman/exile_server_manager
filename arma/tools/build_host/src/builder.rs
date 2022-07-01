use serde::{Deserialize, Serialize};
use std::io::{self, Write};
use std::process::Command as SystemCommand;
use std::sync::atomic::Ordering;
use std::time::Duration;
use vfs::{PhysicalFS, VfsPath};

use crate::{
    server::Server, transfer::Transfer, BuildArch, BuildEnv, BuildError, BuildOS, BuildResult,
    Command, Commands, LogLevel,
};

use colored::*;
use lazy_static::lazy_static;
use regex::Regex;

pub struct Builder {
    os: BuildOS,
    arch: BuildArch,
    env: BuildEnv,
    log_level: LogLevel,
    bot_host: String,
    local_git_path: VfsPath,
    local_build_path: VfsPath,
    remote_build_directory: VfsPath,
    extension_build_target: String,
    server: Server,
}

impl Builder {
    pub fn new(command: Commands) -> Result<Self, BuildError> {
        let (build_x32, os, log_level, env, bot_host) = match command {
            Commands::Run {
                build_x32,
                target,
                log_level,
                env,
                bot_host,
            } => (build_x32, target, log_level, env, bot_host),
        };

        let arch = if build_x32 {
            BuildArch::X32
        } else {
            BuildArch::X64
        };

        let root_path = VfsPath::new(PhysicalFS::new("/"));

        // Have to remove the first slash in order for this to work
        let local_git_path = root_path
            .join(&std::env::current_dir()?.to_string_lossy()[1..])
            .unwrap();

        let local_build_path = local_git_path.join("target")?;

        let remote_build_directory = match os {
            BuildOS::Windows => root_path.join("temp")?.join("esm")?,
            BuildOS::Linux => local_build_path.join("esm")?,
        };

        let extension_build_target: String = match os {
            BuildOS::Windows => match arch {
                BuildArch::X32 => "i686-pc-windows-msvc".into(),
                BuildArch::X64 => "x86_64-pc-windows-msvc".into(),
            },
            BuildOS::Linux => match arch {
                BuildArch::X32 => "i686-unknown-linux-gnu".into(),
                BuildArch::X64 => "x86_64-unknown-linux-gnu".into(),
            },
        };

        let builder = Builder {
            os,
            arch,
            env,
            bot_host,
            log_level,
            local_git_path,
            local_build_path,
            remote_build_directory,
            extension_build_target,
            server: Server::new(),
        };

        Ok(builder)
    }

    fn print_status<F>(
        &mut self,
        message: impl Into<String> + std::fmt::Display,
        code: F,
    ) -> BuildResult
    where
        F: Fn(&mut Builder) -> BuildResult,
    {
        print!("{} - {message} ... ", "<esm_bt>".blue().bold());
        io::stdout().flush().expect("Failed to flush stdout");

        match code(self) {
            Ok(_) => {
                println!("{}", "done".green().bold());
                Ok(())
            }
            Err(e) => {
                println!("{}", "failed".red().bold());
                Err(e)
            }
        }
    }

    fn print_info(&self) {
        println!(
            "{}\n{}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {}\n  {:17}: {}\n",
            "------------------------------------------".black().bold(),
            "ESM Build tool".blue().bold(),
            "OS".black().bold(), self.os,
            "ARCH".black().bold(), self.arch,
            "ENV".black().bold(), self.env,
            "LOG LEVEL".black().bold(), self.log_level,
            "GIT DIRECTORY".black().bold(), self.local_git_path.as_str(),
            "BUILD DIRECTORY".black().bold(), self.remote_build_directory.as_str()
        )
    }

    pub fn start(&mut self) -> BuildResult {
        self.print_info();
        self.print_status("Starting build server", Builder::start_server)?;
        self.print_status("Waiting for build receiver", Builder::wait_for_receiver)?;
        self.print_status("Killing Arma", Builder::kill_arma)?;
        self.print_status("Cleaning directories", Builder::clean_directories)?;
        self.print_status("Writing server config", Builder::create_server_config)?;
        self.print_status("Compiling esm_arma", Builder::build_extension)?;
        Ok(())
    }

    pub fn teardown(&mut self) {
        self.server.stop();
    }

    fn send_to_receiver(&mut self, command: Command) -> BuildResult {
        self.server.send(command)
    }

    fn start_server(&mut self) -> BuildResult {
        self.server.start();
        Ok(())
    }

    fn wait_for_receiver(&mut self) -> BuildResult {
        while !self.server.connected.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_secs(1))
        }

        Ok(())
    }

    fn system_command<'a>(&'a mut self, command: &'a str, args: Vec<&'a str>) -> BuildResult {
        lazy_static! {
            static ref WHITESPACE_REGEX: Regex = Regex::new(r"\t|\s+").unwrap();
        }

        match self.os {
            BuildOS::Windows => {
                let command_file_path = self.local_build_path.join(".esm-build-command").unwrap();
                let command_result_path =
                    self.local_build_path.join(".esm-build-command-result")?;

                // Removes the "Preparing modules for first use." errors that powershell return
                let script = format!(
                    "$ProgressPreference = 'SilentlyContinue'; {command} {}",
                    args.join(" ")
                );

                let script = WHITESPACE_REGEX.replace_all(&script, " ");
                command_file_path
                    .create_file()?
                    .write_all(script.as_bytes())?;

                // Convert the command file into UTF-16LE as required by Microsoft
                match SystemCommand::new("iconv")
                    .arg("-t UTF-16LE")
                    .arg(format!("--output={}", command_result_path.as_str()))
                    .arg(command_file_path.as_str())
                    .output()
                {
                    Ok(_o) => (),
                    Err(e) => return Err(BuildError::Generic(e.to_string())),
                };

                // To avoid dealing with UTF in rust - just have linux convert it to base64
                let base64_output = match SystemCommand::new("base64")
                    .arg(&command_result_path.as_str())
                    .output()
                {
                    Ok(p) => p,
                    Err(e) => return Err(BuildError::Generic(e.to_string())),
                };

                let mut encoded_command =
                    String::from_utf8_lossy(&base64_output.stdout).to_string();

                // Remove the trailing newline
                encoded_command.pop();

                // Finally send the command to powershell
                self.send_to_receiver(Command::System(
                    "powershell".into(),
                    vec!["-EncodedCommand".to_string(), encoded_command],
                ))?;
            }
            BuildOS::Linux => {
                self.send_to_receiver(Command::System(
                    command.to_string(),
                    args.iter().map(|a| a.to_string()).collect(),
                ))?;
            }
        }

        Ok(())
    }

    fn kill_arma(&mut self) -> BuildResult {
        lazy_static! {
            static ref WINDOWS_EXES: Vec<&'static str> = vec![
                "arma3server.exe",
                "arma3server_x64.exe",
                "arma3_x64.exe",
                "arma3.exe",
                "arma3battleye.exe"
            ];
            static ref LINUX_EXES: Vec<&'static str> = vec!["arma3server", "arma3server_x64"];
        };

        let mut script = String::new();
        match self.os {
            BuildOS::Windows => {
                for exe in WINDOWS_EXES.iter() {
                    script.push_str(&format!("Stop-Process -Name {exe};"));
                }
            }
            BuildOS::Linux => {
                for exe in LINUX_EXES.iter() {
                    script.push_str(&format!("pkill {exe};"));
                }
            }
        }

        self.system_command(&script, vec![])
    }

    fn clean_directories(&mut self) -> BuildResult {
        // Local directories
        let esm_path = self.local_build_path.join("@esm")?;

        // Delete @esm and recreate it
        esm_path.remove_dir_all()?;
        esm_path.create_dir_all()?;

        // Create @esm/addons
        esm_path.join("addons")?.create_dir_all()?;

        /////////////////////
        // Remote directories
        let script = match self.os {
            BuildOS::Windows => {
                format!(
                    r#"
                        New-Item -Path "C:\{build_directory}\esm" -ItemType Directory;
                        New-Item -Path "C:\{build_directory}\@esm" -ItemType Directory;
                        New-Item -Path "C:\{build_directory}\@esm\addons" -ItemType Directory;
                    "#,
                    build_directory = &self.remote_build_directory.as_str()[1..],
                )
            }
            BuildOS::Linux => todo!(),
        };

        self.system_command(&script, vec![])
    }

    fn create_server_config(&mut self) -> BuildResult {
        #[derive(Debug, PartialEq, Serialize, Deserialize)]
        struct Config {
            connection_url: String,
            log_level: String,
            env: String,
        }

        let config = Config {
            connection_url: self.bot_host.clone(),
            log_level: self.log_level.to_string(),
            env: self.env.to_string(),
        };

        let config_yaml = serde_yaml::to_vec(&config)?;
        self.local_build_path
            .join("@esm")?
            .join("config.yml")?
            .create_file()?
            .write_all(&config_yaml)?;

        Ok(())
    }

    fn build_extension(&mut self) -> BuildResult {
        // Copy the extension over to the remote host
        Transfer::directory(
            &mut self.server,
            self.local_git_path.join("esm")?,
            self.remote_build_directory.to_owned(),
        )?;

        match self.os {
            BuildOS::Windows => {
                // let script = format!(
                //     "cd {}; rustup run stable-{build_target} cargo build --target {build_target} --release",
                //     self.remote_build_directory.join("esm")?.as_str(),
                //     build_target = self.extension_build_target
                // );

                // self.system_command(&script, vec![])?;
            }
            BuildOS::Linux => {
                // TODO: Build locally and copy to build directory
            }
        }

        Ok(())
    }
}
