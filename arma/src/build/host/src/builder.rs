use common::write_lock;
use glob::glob;
use parking_lot::RwLock;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::Ordering;
use std::time::Duration;

use crate::config::Config;
use crate::file_watcher::FileWatcher;
use crate::Args;
use crate::{
    build_steps, read_lock, BuildArch, BuildEnv, BuildError, BuildOS, BuildResult, Command,
    LogLevel, System,
};

use colored::*;
use lazy_static::lazy_static;
use regex::Regex;
use run_script::ScriptOptions;
use std::fs;

pub struct Remote {
    pub build_path: PathBuf,
    pub build_path_str: String,
    pub server_path: String,
    pub server_args: String,
}

impl Remote {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        Remote {
            build_path: Path::new("/").to_path_buf(),
            build_path_str: "/".into(),
            server_path: String::new(),
            server_args: String::new(),
        }
    }
}

pub struct Builder {
    pub redis: redis::Client,
    /// For storing remote paths and other data
    pub remote: Remote,
    /// The OS to build the extension on
    pub os: BuildOS,
    /// 32 bit or 64 bit
    pub arch: BuildArch,
    /// The environment the extension is built for
    pub env: BuildEnv,
    /// Controls how detailed the logs are
    pub log_level: LogLevel,
    /// The host URI that is currently hosting a bot instance.
    pub bot_host: String,
    /// If true, this ignores file checks and rebuilds the entire suite
    pub force: bool,
    /// If true, marks this build as a release for public build
    pub release: bool,
    /// Controls which pieces are built
    pub only: String,
    /// The path to this repo's root directory
    pub local_git_path: PathBuf,
    /// Rust's build directory
    pub local_build_path: PathBuf,
    /// Rust build target for the build OS
    pub extension_build_target: String,
    /// Handles file watching for changes
    pub file_watcher: FileWatcher,
    /// The config for various build functions
    pub config: Config,
}

impl Builder {
    pub fn new(args: Args) -> Result<Self, BuildError> {
        let arch = if args.build_x32 {
            BuildArch::X32
        } else {
            BuildArch::X64
        };

        let local_git_path = std::env::current_dir()?;

        let extension_build_target: String = match args.target {
            BuildOS::Windows => match arch {
                BuildArch::X32 => "i686-pc-windows-msvc".into(),
                BuildArch::X64 => "x86_64-pc-windows-msvc".into(),
            },
            BuildOS::Linux => match arch {
                BuildArch::X32 => "i686-unknown-linux-gnu".into(),
                BuildArch::X64 => "x86_64-unknown-linux-gnu".into(),
            },
        };

        let local_build_path = local_git_path.join("target");
        let config_path = local_git_path.join("config.yml");

        let file_watcher = FileWatcher::new(&local_git_path, &local_build_path)
            .watch(&local_git_path.join("src").join("@esm"))
            .watch(&local_git_path.join("src").join("arma"))
            .watch(&local_git_path.join("src").join("message"))
            .ignore(&local_git_path.join("src").join("arma").join(".build-sha"))
            .load()?;

        let builder = Builder {
            os: args.target,
            arch,
            env: args.env,
            bot_host: args.bot_host,
            log_level: args.log_level,
            force: args.force,
            release: args.release,
            only: args.only.unwrap_or_default(),
            local_git_path,
            extension_build_target,
            local_build_path,
            remote: Remote::new(),
            redis: redis::Client::open("redis://127.0.0.1/0")?,
            file_watcher,
            config: crate::config::parse(config_path)?,
        };

        Ok(builder)
    }

    pub fn start(&mut self) -> BuildResult {
        self.start_server()?;

        self.print_status("Waiting for build target", Self::wait_for_receiver)?;

        println!(
            r#"{label} - Build details
  {os_label:17}: {os:?}
  {arch_label:17}: {arch:?}
  {env_label:17}: {env:?}
  {log_label:17}: {log}
  {git_dir_label:17}: {git_directory}
  {build_dir_label:17}: {build_directory}
  {server_dir_label:17}: {server_directory}"#,
            label = "<esm_bt>".blue().bold(),
            os_label = "os".black().bold(),
            arch_label = "arch".black().bold(),
            env_label = "env".black().bold(),
            log_label = "log level".black().bold(),
            git_dir_label = "git directory".black().bold(),
            build_dir_label = "build directory".black().bold(),
            server_dir_label = "server directory".black().bold(),
            os = self.os,
            arch = format!("{:?}", self.arch).to_lowercase(),
            env = format!("{:?}", self.env).to_lowercase(),
            log = format!("{:?}", self.log_level).to_lowercase(),
            git_directory = self.local_git_path.to_string_lossy(),
            build_directory = self.remote_build_path_str(),
            server_directory = self.remote.server_path
        );

        self.print_status("Starting build", build_steps::prepare_to_build)?;

        if matches!(self.os, BuildOS::Windows) && self.rebuild_mod() {
            self.print_status("Checking for p drive", build_steps::check_for_p_drive)?;
        }

        if self.rebuild_mod() {
            self.print_status("Building mod", build_steps::build_mod)?;
        }

        if self.rebuild_extension() {
            self.print_status("Compiling extension", build_steps::build_extension)?;
        }

        self.print_status("Seeding database", build_steps::seed_database)?;
        self.print_status("Starting a3 server", build_steps::start_a3_server)?;
        self.print_status("Starting log stream", build_steps::stream_logs)?;
        // self.print_status("Starting a3 client", build_steps::start_a3_client)?; // If flag is set
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

    pub fn send_to_receiver(&mut self, command: Command) -> Result<Command, BuildError> {
        let result = RwLock::new(None);
        write_lock(&crate::SERVER, |mut server| {
            *result.write() = Some(server.send(command.to_owned()));
            Ok(true)
        })?;

        if result.write().is_none() {
            return Err("Failed to send".to_string().into());
        }

        let mut writer = result.write();
        writer.take().unwrap()
    }

    fn start_server(&mut self) -> BuildResult {
        if let Err(e) = self.redis.get_connection() {
            return Err(format!("Redis server - {}", e).into());
        }

        write_lock(&crate::SERVER, |mut server| {
            server.start()?;
            Ok(true)
        })
    }

    fn wait_for_receiver(&mut self) -> BuildResult {
        read_lock(&crate::SERVER, |server| {
            if !server.connected.load(Ordering::SeqCst) {
                std::thread::sleep(Duration::from_secs(1));
                return Ok(false);
            }

            Ok(true)
        })?;

        // We're connected, request update
        match self.send_to_receiver(Command::PostInitRequest) {
            Ok(ref res) => {
                if let Command::PostInit(post_init) = res {
                    let path = post_init.build_path.to_owned();

                    self.remote = Remote {
                        build_path: Path::new(&path).to_path_buf(),
                        build_path_str: path,
                        server_path: post_init.server_path.to_owned(),
                        server_args: post_init.server_args.to_owned(),
                    }
                } else {
                    return Err("Invalid response from receiver".to_string().into());
                }
            }
            Err(e) => return Err(e),
        };

        Ok(())
    }

    pub fn system_command(&mut self, command: &mut System) -> Result<Command, BuildError> {
        lazy_static! {
            static ref WHITESPACE_REGEX: Regex = Regex::new(r"\t|\s+").unwrap();
        }

        match self.os {
            BuildOS::Windows => {
                let command_file_path = self.local_build_path.join(".esm-build-command");
                let command_result_path = self.local_build_path.join(".esm-build-command-result");

                // Removes the "Preparing modules for first use." errors that powershell return
                let script = format!(
                    "$ProgressPreference = 'SilentlyContinue'; {} {}",
                    command.command,
                    command.arguments.join(" ")
                );

                let script = WHITESPACE_REGEX.replace_all(&script, " ");
                fs::write(&command_file_path, script.as_bytes())?;

                // Convert the command file into UTF-16LE as required by Microsoft
                local_command(
                    "iconv",
                    vec![
                        "-t UTF-16LE",
                        &format!("--output={}", command_result_path.display()),
                        &command_file_path.to_string_lossy(),
                    ],
                )?;

                // To avoid dealing with UTF in rust - just have linux convert it to base64
                let mut encoded_command =
                    local_command("base64", vec![&command_result_path.to_string_lossy()])?;

                // Remove the trailing newline
                encoded_command.pop();

                command.command("powershell");
                command.arguments(vec!["-EncodedCommand".to_string(), encoded_command]);

                // Finally send the command to powershell
                self.send_to_receiver(Command::System(command.to_owned()))
            }
            BuildOS::Linux => self.send_to_receiver(Command::System(command.to_owned())),
        }
    }

    pub fn remote_build_path(&self) -> &PathBuf {
        &self.remote.build_path
    }

    pub fn remote_build_path_str(&self) -> &str {
        &self.remote.build_path_str
    }

    pub fn rebuild_extension(&self) -> bool {
        // Force? Forced true
        // Just building the extension? Forced true
        // Just building just the mod? Forced false
        // No force, no only? return true only if the files have changed
        (self.force || self.only != "mod")
            && (self.force
                || self.only == "extension"
                || has_directory_changed(
                    &self.file_watcher,
                    &self.local_git_path.join("src").join("arma"),
                )
                || has_directory_changed(
                    &self.file_watcher,
                    &self.local_git_path.join("src").join("message"),
                ))
    }

    // The entire mod
    pub fn rebuild_mod(&self) -> bool {
        // Force? Forced true
        // Just building the mod? Forced true
        // Just building just the extension? Forced false
        // No force, no only? return true only if the files have changed
        (self.force || self.only != "extension")
            && (self.force
                || self.only == "mod"
                || has_directory_changed(
                    &self.file_watcher,
                    &self.local_git_path.join("src").join("@esm"),
                ))
    }

    // Single addon
    pub fn rebuild_addon(&self, addon: &str) -> bool {
        // Force? Forced true
        // Just building the mod? Forced true
        // Just building just the extension? Forced false
        // No force, no only? return true only if the files have changed
        (self.force || self.only != "extension")
            && (self.force
                || self.only == "mod"
                || has_directory_changed(
                    &self.file_watcher,
                    &self
                        .local_git_path
                        .join("src")
                        .join("@esm")
                        .join("addons")
                        .join(addon),
                ))
    }
}

pub fn local_command(cmd: &str, args: Vec<&str>) -> Result<String, BuildError> {
    let options = ScriptOptions::new();
    let (code, output, error) = run_script::run(
        &format!("{} {}", cmd, args.join(" ").as_str()),
        &vec![],
        &options,
    )
    .unwrap();

    if code == 0 {
        return Ok(output);
    }

    Err(error.into())
}

pub fn git_sha_short() -> String {
    match local_command("git", vec!["rev-parse", "--short", "HEAD"]) {
        Ok(o) => o.trim().to_string(),
        Err(_e) => "FAILED TO RETRIEVE".into(),
    }
}

pub fn has_directory_changed(watcher: &FileWatcher, path: &Path) -> bool {
    let file_paths = match glob(&format!("{}/**/*", path.to_string_lossy())) {
        Ok(p) => p,
        Err(_e) => return true,
    };

    file_paths
        .filter_map(|p| p.ok())
        .any(|p| watcher.was_modified(&p))
}
