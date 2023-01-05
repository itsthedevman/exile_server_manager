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
use crate::{build_steps, read_lock, BuildArch, BuildError, BuildOS, BuildResult, Command, System};

use colored::*;
use lazy_static::lazy_static;
use regex::Regex;
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
    /// Arguments passed in from the user
    pub args: Args,
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
    /// The matching executable plus extension for this build
    pub server_executable: String,
}

impl Builder {
    pub fn new(args: Args) -> Result<Self, BuildError> {
        let local_git_path = std::env::current_dir()?;

        let arch = args.build_arch();
        let os = args.build_os();

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

        let server_executable: String = match os {
            BuildOS::Linux => match arch {
                BuildArch::X32 => "arma3server.so".into(),
                BuildArch::X64 => "arma3server_x64.so".into(),
            },
            BuildOS::Windows => match arch {
                BuildArch::X32 => "arma3server.exe".into(),
                BuildArch::X64 => "arma3server_x64.exe".into(),
            },
        };

        let local_build_path = local_git_path.join("target");
        let config_path = local_git_path.join("config.yml");

        let file_watcher = FileWatcher::new(&local_git_path, &local_build_path)
            .watch(&local_git_path.join("src").join("@esm"))
            .watch(&local_git_path.join("src").join("arma"))
            .watch(&local_git_path.join("src").join("message"))
            .watch(&local_git_path.join("src").join("build").join("receiver"))
            .ignore(&local_git_path.join("src").join("arma").join(".build-sha"))
            .load()?;

        let builder = Builder {
            args,
            local_git_path,
            extension_build_target,
            local_build_path,
            remote: Remote::new(),
            redis: redis::Client::open("redis://127.0.0.1/0")?,
            file_watcher,
            config: crate::config::parse(config_path)?,
            server_executable,
        };

        Ok(builder)
    }

    pub fn start(&mut self) -> BuildResult {
        self.print_header();

        if matches!(self.args.build_os(), BuildOS::Linux) {
            self.print_status("Preparing container", build_steps::start_container)?;
            self.print_status("Waiting for container", build_steps::wait_for_container)?;
            self.print_status("Preparing arma3server", build_steps::update_arma)?;

            // if self.rebuild_receiver() {
            self.print_status("Building receiver", build_steps::build_receiver)?;
            // }
        }

        self.start_server()?;
        self.print_status("Waiting for build target", Self::wait_for_receiver)?;

        self.print_build_info();

        self.print_status("Starting build", build_steps::prepare_to_build)?;

        if matches!(self.args.build_os(), BuildOS::Windows) && self.rebuild_mod() {
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

        match self.args.build_os() {
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

                System::new()
                    .command("iconv")
                    .arguments(&[
                        "-t UTF-16LE",
                        &format!("--output={}", command_result_path.display()),
                        &command_file_path.to_string_lossy(),
                    ])
                    .execute()?;

                // To avoid dealing with UTF in rust - just have linux convert it to base64
                let mut encoded_command = System::new()
                    .command("base64")
                    .arguments(&[&*command_result_path.to_string_lossy()])
                    .execute()?;

                // Remove the trailing newline
                encoded_command.pop();

                command.command("powershell");
                command.arguments(&["-EncodedCommand".to_string(), encoded_command]);

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
        (self.args.force_rebuild() || self.args.build_only() != "mod")
            && (self.args.force_rebuild()
                || self.args.build_only() == "extension"
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
        (self.args.force_rebuild() || self.args.build_only() != "extension")
            && (self.args.force_rebuild()
                || self.args.build_only() == "mod"
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
        (self.args.force_rebuild() || self.args.build_only() != "extension")
            && (self.args.force_rebuild()
                || self.args.build_only() == "mod"
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

    pub fn rebuild_receiver(&self) -> bool {
        self.args.force_rebuild()
            || has_directory_changed(
                &self.file_watcher,
                &self
                    .local_git_path
                    .join("src")
                    .join("build")
                    .join("receiver"),
            )
    }

    fn print_header(&self) {
        let label = "<esm_bt>".blue().bold();
        let mut header = format!("{label} ---------------------\n{label} - ESM Build Tool");

        /*
            <esm_bt> ---------------------
            <esm_bt> - ESM Build Tool
            <esm_bt> -   Building
            <esm_bt> -     receiver
            <esm_bt> -     mod
            <esm_bt> -     extension
            <esm_bt> ---------------------
        */
        let building = [
            ["receiver", &self.rebuild_receiver().to_string()],
            ["mod", &self.rebuild_mod().to_string()],
            ["extension", &self.rebuild_extension().to_string()],
        ];

        let building_section: Vec<String> = building
            .iter()
            .filter_map(|i| {
                if i[1] == "true" {
                    Some(format!("{label} -     {}", i[0]))
                } else {
                    None
                }
            })
            .collect();

        if !building_section.is_empty() {
            header.push_str(&format!(
                "\n{label} -   Building\n{}",
                &building_section.join("\n")
            ));
        }

        println!("{}\n{label} ---------------------", header);
    }

    fn print_build_info(&self) {
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
            os = self.args.build_os(),
            arch = format!("{:?}", self.args.build_arch()).to_lowercase(),
            env = format!("{:?}", self.args.build_env()).to_lowercase(),
            log = format!("{:?}", self.args.log_level()).to_lowercase(),
            git_directory = self.local_git_path.to_string_lossy(),
            build_directory = self.remote_build_path_str(),
            server_directory = self.remote.server_path
        );
    }
}

pub fn git_sha_short() -> String {
    match System::new()
        .command("git")
        .arguments(&["rev-parse", "--short", "HEAD"])
        .add_detection(r"[a-fA-F0-9]+")
        .execute()
    {
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
