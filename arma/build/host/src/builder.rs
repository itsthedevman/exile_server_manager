use serde::{Deserialize, Serialize};
use std::io::{self, Write};
use std::process::Output;
use std::sync::atomic::Ordering;
use std::time::Duration;
use vfs::{PhysicalFS, VfsPath};

use crate::database::Database;
use crate::Directory;
use crate::{
    server::Server, BuildArch, BuildEnv, BuildError, BuildOS, BuildResult, Command, Commands, File,
    LogLevel, System, SystemCommand,
};

use colored::*;
use lazy_static::lazy_static;
use regex::Regex;

pub struct Builder {
    /// For sending messages
    server: Server,
    /// The OS to build the extension on
    os: BuildOS,
    /// 32 bit or 64 bit
    arch: BuildArch,
    /// The environment the extension is built for
    env: BuildEnv,
    /// Controls how detailed the logs are
    log_level: LogLevel,
    /// The host URI that is currently hosting a bot instance.
    bot_host: String,
    /// The path to this repo's root directory
    local_git_path: VfsPath,
    /// Rust's build directory
    local_build_path: VfsPath,
    /// The temp directory on the build OS
    remote_build_directory: VfsPath,
    /// Rust build target for the build OS
    extension_build_target: String,
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

    pub fn start(&mut self) -> BuildResult {
        self.print_info();
        self.print_status("Starting build host", Builder::start_server)?;
        self.print_status("Waiting for build receiver", Builder::wait_for_receiver)?;
        self.print_status("Killing Arma", Builder::kill_arma)?;
        self.print_status("Cleaning directories", Builder::clean_directories)?;
        self.print_status("Writing server config", Builder::create_server_config)?;
        self.print_status("Compiling esm_arma", Builder::build_extension)?;
        self.print_status("Building @esm", Builder::build_mod)?;
        self.print_status("Seeding database", Builder::seed_database)?;
        Ok(())
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

        // Forces print to write
        if let Err(e) = io::stdout().flush() {
            println!("{}", "failed".red().bold());
            return Err(e.to_string().into());
        }

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
            "{}\n  {:17}: {}\n  {:17}: {}\n  {:17}: {}\n  {:17}: {}\n  {:17}: {}\n  {:17}: {}\n",
            "ESM Build Tool".blue().bold(),
            "os".black().bold(),
            format!("{:?}", self.os).to_lowercase(),
            "arch".black().bold(),
            format!("{:?}", self.arch).to_lowercase(),
            "env".black().bold(),
            format!("{:?}", self.env).to_lowercase(),
            "log level".black().bold(),
            format!("{:?}", self.log_level).to_lowercase(),
            "git directory".black().bold(),
            self.local_git_path.as_str(),
            "build directory".black().bold(),
            self.remote_build_directory.as_str()
        )
    }

    pub fn teardown(&mut self) {
        self.server.stop();
    }

    fn send_to_receiver(&mut self, command: Command) -> Result<Command, BuildError> {
        self.server.send(command)
    }

    fn start_server(&mut self) -> BuildResult {
        self.server.start()
    }

    fn wait_for_receiver(&mut self) -> BuildResult {
        while !self.server.connected.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_secs(1))
        }

        Ok(())
    }

    fn system_command(&mut self, command: System) -> BuildResult {
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
                    "$ProgressPreference = 'SilentlyContinue'; {} {}",
                    command.cmd,
                    command.args.join(" ")
                );

                let script = WHITESPACE_REGEX.replace_all(&script, " ");
                command_file_path
                    .create_file()?
                    .write_all(script.as_bytes())?;

                // Convert the command file into UTF-16LE as required by Microsoft
                local_command(
                    "iconv",
                    vec![
                        "-t UTF-16LE",
                        &format!("--output={}", command_result_path.as_str()),
                        command_file_path.as_str(),
                    ],
                )?;

                // To avoid dealing with UTF in rust - just have linux convert it to base64
                let base64_output = local_command("base64", vec![command_result_path.as_str()])?;

                let mut encoded_command =
                    String::from_utf8_lossy(&base64_output.stdout).to_string();

                // Remove the trailing newline
                encoded_command.pop();

                let command = System {
                    cmd: "powershell".into(),
                    args: vec!["-EncodedCommand".to_string(), encoded_command],
                    check_for_success: command.check_for_success,
                    success_regex: command.success_regex,
                };

                // Finally send the command to powershell
                match self.send_to_receiver(Command::System(command)) {
                    Ok(_) => Ok(()),
                    Err(e) => Err(e),
                }
            }
            BuildOS::Linux => match self.send_to_receiver(Command::System(command)) {
                Ok(_) => Ok(()),
                Err(e) => Err(e),
            },
        }
    }

    fn kill_arma(&mut self) -> BuildResult {
        lazy_static! {
            static ref WINDOWS_EXES: &'static [&'static str] = &[
                "arma3server.exe",
                "arma3server_x64.exe",
                "arma3_x64.exe",
                "arma3.exe",
                "arma3battleye.exe"
            ];
            static ref LINUX_EXES: &'static [&'static str] = &["arma3server", "arma3server_x64"];
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

        self.system_command(System {
            cmd: script,
            args: vec![],
            check_for_success: false,
            success_regex: "".into(),
        })
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
                        $Dirs = "C:\{build_directory}\esm",
                                "C:\{build_directory}\@esm",
                                "C:\{build_directory}\@esm\addons";

                        Foreach ($dir in $Dirs) {{
                            if (![System.IO.Directory]::Exists($dir)) {{
                                New-Item -Path $dir -ItemType Directory;
                            }}
                        }}
                    "#,
                    build_directory = &self.remote_build_directory.as_str()[1..],
                )
            }
            BuildOS::Linux => todo!(),
        };

        self.system_command(System {
            cmd: script,
            args: vec![],
            check_for_success: false,
            success_regex: "".into(),
        })
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
        // This will be read by the build script and inserted into the extension
        let extension_path = self.local_git_path.join("esm")?;
        extension_path
            .join(".build-sha")?
            .create_file()?
            .write_all(&git_sha_short())?;

        match self.os {
            BuildOS::Windows => {
                // Copy the extension over to the remote host
                Directory::transfer(
                    &mut self.server,
                    extension_path,
                    self.remote_build_directory.to_owned(),
                )?;

                let script = format!(
                    r#"
                        cd 'C:\{build_directory}\esm';
                        rustup run stable-{build_target} cargo build --target {build_target} --release
                    "#,
                    build_directory = &self.remote_build_directory.as_str()[1..],
                    build_target = self.extension_build_target
                );

                self.system_command(System {
                    cmd: script,
                    args: vec![],
                    check_for_success: true,
                    success_regex: r#"(?i)finished release \[optimized\]"#.into(),
                })?;
            }
            BuildOS::Linux => todo!(),
        }

        Ok(())
    }

    fn build_mod(&mut self) -> BuildResult {
        lazy_static! {
            static ref ADDONS: Vec<&'static str> = vec![
                "exile_server_manager",
                "exile_server_overwrites",
                "exile_server_xm8",
                "exile_server_hacking",
                "exile_server_grinding",
                "exile_server_charge_plant_started",
                "exile_server_flag_steal_started",
                "exile_server_player_connected"
            ];
            static ref DIRECTORIES: Vec<&'static str> = vec!["optionals", "sql"];
            static ref FILES: Vec<&'static str> = vec!["Licenses.txt"];
        }

        // Set up all the paths needed
        let mod_path = self.local_git_path.join("@esm")?;
        let source_path = mod_path.join("addons")?;

        let mod_build_path = self.local_build_path.join("@esm")?;
        let addon_destination_path = mod_build_path.join("addons")?;

        let mikero_path = self.local_git_path.join("tools")?.join("depbo-tools")?;

        // Create the PBOs
        for addon in ADDONS.iter() {
            let result = SystemCommand::new(mikero_path.join("bin")?.join("makepbo")?.as_str())
                .env("LD_LIBRARY_PATH", mikero_path.join("lib")?.as_str())
                .args(vec![
                    &format!("{}/{addon}", source_path.as_str()),
                    &format!("{}/{addon}.pbo", addon_destination_path.as_str()),
                ])
                .output()?;

            if !result.status.success() {
                let output = format!(
                    "Failed to build {addon}.pbo\n{}\n{}\n\n{}\n{}",
                    "stdout".green().bold(),
                    String::from_utf8_lossy(&result.stdout).black(),
                    "stderr".red().bold(),
                    String::from_utf8_lossy(&result.stderr).red()
                );

                return Err(output.into());
            }
        }

        // Copy the rest of the mod contents
        for directory in DIRECTORIES.iter() {
            Directory::copy(&mod_path.join(directory)?, &mod_build_path.join(directory)?)?
        }

        for file in FILES.iter() {
            File::copy(&mod_path.join(file)?, &mod_build_path.join(file)?)?
        }

        Ok(())
    }

    fn seed_database(&mut self) -> BuildResult {
        let data = crate::data::parse_data_file(
            self.local_git_path.join("build")?.join("test_data.yml")?,
        )?;

        let sql = Database::generate_sql(data);

        // match self.send_to_receiver(Command::Database(sql)) {
        //     Ok(_) => Ok(()),
        //     Err(e) => Err(e),
        // }
        Ok(())
    }
}

fn local_command(cmd: &str, args: Vec<&str>) -> Result<Output, BuildError> {
    match SystemCommand::new(cmd).args(args).output() {
        Ok(o) => Ok(o),
        Err(e) => Err(BuildError::Generic(e.to_string())),
    }
}

fn git_sha_short() -> Vec<u8> {
    match local_command("git", vec!["rev-parse", "--short", "HEAD"]) {
        Ok(o) => o.stdout,
        Err(_e) => "FAILED TO RETRIEVE".into(),
    }
}
