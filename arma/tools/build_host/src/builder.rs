use std::fs::File;
use std::io::{self, Write};
use std::process::Command;
use std::sync::atomic::Ordering;
use std::time::Duration;

use super::{
    server::{NetworkCommands, Server},
    BuildArch, BuildEnv, BuildOS, LogLevel,
};

use colored::*;
use lazy_static::lazy_static;
use regex::Regex;

pub struct Builder {
    os: BuildOS,
    arch: BuildArch,
    env: BuildEnv,
    log_level: LogLevel,
    git_directory: String,
    build_directory: String,
    local_build_directory: String,
    server: Server,
}

impl Builder {
    pub fn new(build_x32: bool, os: BuildOS, log_level: LogLevel, env: BuildEnv) -> Self {
        let git_directory = match std::env::current_dir() {
            Ok(d) => d.to_string_lossy().to_string(),
            Err(e) => panic!("{e}"),
        };

        let local_build_directory = format!("{}/target", git_directory);
        let build_directory = match os {
            BuildOS::Windows => "C:\\temp\\@esm".to_string(),
            BuildOS::Linux => format!("{local_build_directory}/@esm"),
        };

        Builder {
            os,
            arch: if build_x32 {
                BuildArch::X32
            } else {
                BuildArch::X64
            },
            env,
            log_level,
            git_directory,
            build_directory,
            local_build_directory,
            server: Server::new(),
        }
    }

    fn print_status<F>(&mut self, message: impl Into<String> + std::fmt::Display, code: F)
    where
        F: Fn(&mut Builder),
    {
        print!("{} - {message} ... ", "<esm_bt>".blue().bold());
        io::stdout().flush().expect("Failed to flush stdout");
        code(self);
        println!("{}", "done".green().bold());
    }

    pub fn start(&mut self) {
        self.print_info();
        self.print_status("Starting build server", Builder::start_server);
        self.print_status("Waiting for receiver", Builder::wait_for_receiver);
        self.print_status("Killing Arma", Builder::kill_arma);
        self.print_status("Cleaning directories", Builder::clean_directories);
    }

    fn send_to_receiver(&self, command: NetworkCommands) {
        self.server.send(command);
    }

    fn print_info(&self) {
        println!(
            "{}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {:?}\n  {:17}: {}\n  {:17}: {}\n",
            "ESM Build tool".blue().bold(),
            "OS".black().bold(), self.os,
            "ARCH".black().bold(), self.arch,
            "ENV".black().bold(), self.env,
            "LOG LEVEL".black().bold(), self.log_level,
            "GIT DIRECTORY".black().bold(), self.git_directory,
            "BUILD DIRECTORY".black().bold(), self.build_directory
        )
    }

    fn start_server(&mut self) {
        self.server.start();
    }

    fn wait_for_receiver(&mut self) {
        while !self.server.connected.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_secs(1))
        }
    }

    fn system_command<'a>(&'a mut self, command: &'a str, args: Vec<&'a str>) {
        match self.os {
            BuildOS::Windows => {
                let command_file_path =
                    format!("{}/.esm-build-command", self.local_build_directory);

                let command_result_path =
                    format!("{}/.esm-build-command-result", self.local_build_directory);

                let command_file = File::create(&command_file_path).unwrap();
                write!(
                    &command_file,
                    // Removes the "Preparing modules for first use." errors that powershell return
                    "$ProgressPreference = 'SilentlyContinue'\n{command} {}",
                    args.join(" ")
                )
                .unwrap();

                // Convert the command file into UTF-16LE as required by Microsoft
                match Command::new("iconv")
                    .arg("-t UTF-16LE")
                    .arg(format!("--output={}", command_result_path))
                    .arg(&command_file_path)
                    .output()
                {
                    Ok(_o) => (),
                    Err(e) => panic!("Failed to run iconv: {}", e),
                };

                // To avoid dealing with UTF in rust - just have linux convert it to base64
                let base64_output = match Command::new("base64").arg(&command_result_path).output()
                {
                    Ok(p) => p,
                    Err(e) => panic!("Failed to run base64: {}", e),
                };

                let mut encoded_command =
                    String::from_utf8_lossy(&base64_output.stdout).to_string();

                // Remove the trailing newline
                encoded_command.pop();

                // Finally send the command to powershell
                self.send_to_receiver(NetworkCommands::SystemCommand(
                    "powershell".into(),
                    vec!["-EncodedCommand".to_string(), encoded_command],
                ));
            }
            BuildOS::Linux => {
                self.send_to_receiver(NetworkCommands::SystemCommand(
                    command.to_string(),
                    args.iter().map(|a| a.to_string()).collect(),
                ));
            }
        }
    }

    fn kill_arma(&mut self) {
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

        match self.os {
            BuildOS::Windows => {
                for exe in WINDOWS_EXES.iter() {
                    self.system_command("Stop-Process", ["-Name", exe].into());
                }
            }
            BuildOS::Linux => {
                for exe in LINUX_EXES.iter() {
                    self.system_command("pkill", vec![exe]);
                }
            }
        }
    }

    fn clean_directories(&mut self) {
        lazy_static! {
            static ref WHITESPACE_REGEX: Regex = Regex::new(r"\t|\s+").unwrap();
        }

        match self.os {
            BuildOS::Windows => {
                let script = format!(
                    r#"
                        if ( Test-Path -Path "{}" -PathType Container ) {{
                            Start-Process "E:\git\a3_editor_exile.bat"
                        }}
                    "#,
                    self.build_directory
                );

                let script = WHITESPACE_REGEX.replace_all(&script, " ");
                self.system_command(&script, vec![]);
            }
            BuildOS::Linux => {}
        }
    }
}
