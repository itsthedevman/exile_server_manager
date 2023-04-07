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

impl Default for Remote {
    fn default() -> Self {
        Remote {
            build_path: Path::new("/tmp/esm").to_path_buf(),
            build_path_str: "/tmp/esm".into(),
            server_path: String::new(),
            server_args: String::new(),
        }
    }
}

impl Remote {
    pub fn new() -> Self {
        Self::default()
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
    pub rebuild_mod: bool,
    pub rebuild_extension: bool,
    pub rebuild_receiver: bool,
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
                BuildArch::X32 => "arma3server".into(),
                BuildArch::X64 => "arma3server_x64".into(),
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
            .watch(&local_git_path.join("src").join("esm"))
            .watch(&local_git_path.join("src").join("message"))
            .watch(&local_git_path.join("src").join("build").join("receiver"))
            .watch(&local_git_path.join("src").join("build").join("common"))
            .watch(&local_git_path.join("src").join("build").join("compiler"))
            .ignore(&local_git_path.join("src").join("esm").join(".build-sha"))
            .load()?;

        let rebuild_mod = args.full_rebuild();
        let rebuild_extension = args.full_rebuild();
        let rebuild_receiver = args.full_rebuild();

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
            rebuild_mod,
            rebuild_extension,
            rebuild_receiver,
        };

        Ok(builder)
    }

    pub fn run(&mut self) -> BuildResult {
        self.print_header();

        if matches!(self.args.build_os(), BuildOS::Linux) {
            self.print_status("Preparing container", build_steps::start_container)?;
            self.print_status("Waiting for container", build_steps::wait_for_container)?;
            self.print_status("Checking for @exile", build_steps::check_for_files)?;
            self.print_status("Preparing receiver", build_steps::prepare_receiver)?;

            if self.update_arma() {
                self.print_status("Updating arma server", build_steps::update_arma)?;
            }
        }

        self.start_server()?;
        self.print_status("Waiting for build target", Self::wait_for_receiver)?;

        detect_rebuild(self)?;
        self.print_build_info();
        self.print_status("Preparing to build", build_steps::prepare_to_build)?;

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
        let _ = kill_arma(self);
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
        if self.args.build_only() == "mod" {
            return false;
        }

        self.rebuild_extension
            || self.args.build_only() == "extension"
            || has_directory_changed(
                &self.file_watcher,
                &self.local_git_path.join("src").join("esm"),
            )
            || has_directory_changed(
                &self.file_watcher,
                &self.local_git_path.join("src").join("message"),
            )
    }

    // The entire mod
    pub fn rebuild_mod(&self) -> bool {
        if self.args.build_only() == "extension" {
            return false;
        }

        self.rebuild_mod
            || self.args.build_only() == "mod"
            || has_directory_changed(
                &self.file_watcher,
                &self.local_git_path.join("src").join("@esm"),
            )
    }

    // Single addon
    pub fn rebuild_addon(&self, addon: &str) -> bool {
        if self.args.build_only() == "extension" {
            return false;
        }

        self.rebuild_mod
            || self.args.build_only() == "mod"
            || has_directory_changed(
                &self.file_watcher,
                &self
                    .local_git_path
                    .join("src")
                    .join("@esm")
                    .join("addons")
                    .join(addon),
            )
    }

    pub fn rebuild_receiver(&self) -> bool {
        self.rebuild_receiver
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
            .execute(None)
            .unwrap_or_default()
            == "true";

        !files_exist || self.args.update_arma()
    }

    pub fn print_header(&self) {
        let label = "<esm_bt>".blue().bold();
        let header = format!(
            "{label} - : {SEPARATOR}\n{label} - : {:^40}",
            "ESM Arma Build Tool".blue().bold().underline()
        );

        println!("{header}\n{label} - : {SEPARATOR}");
    }

    pub fn print_build_info(&self) {
        let rebuild_extension = self.rebuild_extension();
        let is_windows = matches!(self.args.build_os(), BuildOS::Windows);
        let is_x64 = matches!(self.args.build_arch(), BuildArch::X64);

        let building_section: Vec<&str> = [
            ("@esm", self.rebuild_mod()),
            ("esm.dll", rebuild_extension && is_windows && !is_x64),
            ("esm_x64.dll", rebuild_extension && is_windows && is_x64),
            ("esm.so", rebuild_extension && !is_windows && !is_x64),
            ("esm_x64.so", rebuild_extension && !is_windows && is_x64),
        ]
        .iter()
        .filter_map(|i| if i.1 { Some(i.0) } else { None })
        .collect();

        println!(
            r#"{label} - : {SEPARATOR}
{label} - : {header:^40}
{label} - : {build_queue_label:>17} -> {build_queue}
{label} - : {env_label:>17} -> {env:?}
{label} - : {log_label:>17} -> {log}
{label} - : {git_dir_label:>17} -> {git_directory}
{label} - : {build_dir_label:>17} -> {build_directory}
{label} - : {server_dir_label:>17} -> {server_directory}
{label} - : {SEPARATOR}"#,
            label = "<esm_bt>".blue().bold(),
            header = "Build Details".green().bold().underline(),
            build_queue_label = "queue".bold(),
            env_label = "env".bold(),
            log_label = "log level".bold(),
            git_dir_label = "git directory".bold(),
            build_dir_label = "build directory".bold(),
            server_dir_label = "server directory".bold(),
            build_queue = building_section.join(", "),
            env = self.args.build_env(),
            log = self.args.log_level(),
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
        .execute(None)
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
        .execute(None)?;

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
        .execute(None)?;

    Ok(())
}

pub fn is_container_running() -> bool {
    let Ok(result) = System::new()
        .command("docker")
        .arguments(&[
            "container",
            "inspect",
            "-f",
            "\"{{.State.Status}}\"",
            ARMA_CONTAINER,
        ])
        .add_detection("running").execute(None) else {
        return false;
    };

    result.trim_end() == "running"
}

pub fn docker_dir_exists(file_path: &Path) -> bool {
    let Ok(result) = System::new()
        .command("docker")
        .arguments(&[
            "exec",
            "-t",
            ARMA_CONTAINER,
            "/bin/bash",
            "-c",
            &format!("[ -d {file_path} ] && echo 'exists'", file_path = file_path.display())
        ])
        .add_detection("exists").execute(None) else {
        return false;
    };

    result.trim_end() == "exists"
}
