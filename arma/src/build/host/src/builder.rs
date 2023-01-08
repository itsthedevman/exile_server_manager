use colored::*;
use glob::glob;
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::Ordering;
use std::time::Duration;

use crate::*;

const SEPARATOR: &str = "----------------------------------------";

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
    /// TODO
    pub build_server: Server,
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
            build_server: Server::new(),
        };

        Ok(builder)
    }

    pub fn run(&mut self) -> BuildResult {
        self.print_header();

        if matches!(self.args.build_os(), BuildOS::Linux) {
            self.print_status("Preparing container", build_steps::start_container)?;
            self.print_status("Waiting for container", build_steps::wait_for_container)?;
            self.print_status("Preparing receiver", build_steps::prepare_receiver)?;

            if self.update_arma() {
                self.print_status("Updating arma server", build_steps::update_arma)?;
            }
        }

        self.start_server()?;
        self.print_status("Waiting for build target", Self::wait_for_receiver)?;

        self.print_build_info();
        self.print_status("Preparing to build", build_steps::prepare_to_build)?;

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

    pub fn finish(&mut self) -> BuildResult {
        self.build_server.stop();

        if matches!(self.args.build_os(), BuildOS::Linux) {
            self.print_status("Closing receiver", |_| stop_receiver())?;
        }

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

    fn start_server(&mut self) -> BuildResult {
        // Ensure we're connected to redis
        if let Err(e) = self.redis.get_connection() {
            return Err(format!("Redis server - {}", e).into());
        }

        self.build_server.start()
    }

    fn wait_for_receiver(&mut self) -> BuildResult {
        while !self.build_server.connected.load(Ordering::SeqCst) {
            std::thread::sleep(Duration::from_secs(1));
        }

        // We're connected, request update
        match self.build_server.send(Command::PostInitRequest) {
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

    pub fn update_arma(&self) -> bool {
        let script = "[ -f /arma3server/arma3server ] && echo \"true\"";

        let files_exist = System::new()
            .command("bash")
            .arguments(&[
                "-c",
                &format!("docker exec -t {ARMA_CONTAINER} /bin/bash -c \"{script}\""),
            ])
            .execute()
            .unwrap_or_default()
            == "true";

        !files_exist || self.args.update_arma()
    }

    pub fn print_header(&self) {
        let label = "<esm_bt>".blue().bold();
        let mut header = format!(
            "{label} - : {SEPARATOR}\n{label} - : {:^40}",
            "ESM Arma Build Tool".blue().bold().underline()
        );

        let rebuild_extension = self.rebuild_extension();
        let is_windows = matches!(self.args.build_os(), BuildOS::Windows);
        let is_x64 = matches!(self.args.build_arch(), BuildArch::X64);

        let building_section: Vec<&str> = [
            ("receiver", self.rebuild_receiver()),
            ("@esm", self.rebuild_mod()),
            ("esm.dll", rebuild_extension && is_windows && !is_x64),
            ("esm_x64.dll", rebuild_extension && is_windows && is_x64),
            ("esm.so", rebuild_extension && !is_windows),
        ]
        .iter()
        .filter_map(|i| if i.1 { Some(i.0) } else { None })
        .collect();

        if !building_section.is_empty() {
            header.push_str(&format!(
                "\n{label} - : Build queue: {}",
                &building_section.join(", ").black().bold()
            ));
        }

        println!("{header}\n{label} - : {SEPARATOR}");
    }

    pub fn print_build_info(&self) {
        println!(
            r#"{label} - : {SEPARATOR}
{label} - : {header:^40}
{label} - : {os_label:>17} -> {os:?}
{label} - : {arch_label:>17} -> {arch:?}
{label} - : {env_label:>17} -> {env:?}
{label} - : {log_label:>17} -> {log}
{label} - : {git_dir_label:>17} -> {git_directory}
{label} - : {build_dir_label:>17} -> {build_directory}
{label} - : {server_dir_label:>17} -> {server_directory}
{label} - : {SEPARATOR}"#,
            label = "<esm_bt>".blue().bold(),
            header = "Build Details".green().bold().underline(),
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

pub fn start_receiver() -> BuildResult {
    System::new()
        .command("docker")
        .arguments(&[
            "exec",
            "-td",
            ARMA_CONTAINER,
            "/bin/bash",
            "/arma3server/start_receiver.sh",
        ])
        .add_error_detection("no such")
        .print_as("starting receiver")
        .print()
        .execute()?;

    Ok(())
}

pub fn stop_receiver() -> BuildResult {
    System::new()
        .command("docker")
        .arguments(&[
            "exec",
            "-t",
            ARMA_CONTAINER,
            "/bin/bash",
            "-c",
            "for pid in $(ps -ef | awk '/arma3server\\/receiver/ {print $2}'); do kill -9 $pid; done",
        ])
        .execute()?;

    Ok(())
}
