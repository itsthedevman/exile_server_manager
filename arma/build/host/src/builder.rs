use common::write_lock;
use compiler::Compiler;
use glob::glob;
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::Ordering;
use std::time::Duration;

use crate::config::Config;
use crate::database::Database;
use crate::file_watcher::FileWatcher;
use crate::{
    read_lock, BuildArch, BuildEnv, BuildError, BuildOS, BuildResult, Command, LogLevel, System,
};
use crate::{Args, Directory};

use colored::*;
use lazy_static::lazy_static;
use regex::Regex;
use run_script::ScriptOptions;
use std::{fs, thread};

/// Used with the test suite, this key holds the server's current esm.key
const REDIS_SERVER_KEY: &str = "test_server_key";

const ADDONS: &[&str] = &[
    "exile_server_manager",
    "exile_server_overwrites",
    "exile_server_xm8",
    "exile_server_hacking",
    "exile_server_grinding",
    "exile_server_charge_plant_started",
    "exile_server_flag_steal_started",
    "exile_server_player_connected",
];

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
    file_watcher: FileWatcher,
    /// The config for various build functions
    config: Config,
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
            .watch(&local_git_path.join("@esm"))
            .watch(&local_git_path.join("arma"))
            .watch(&local_git_path.join("message"))
            .ignore(&local_git_path.join("arma").join(".build-sha"))
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

        self.print_status("Starting build", Self::prepare_to_build)?;

        if matches!(self.os, BuildOS::Windows) && self.rebuild_mod() {
            self.print_status("Checking for p drive", Self::check_for_p_drive)?;
        }

        if self.rebuild_mod() {
            self.print_status("Building mod", Self::build_mod)?;
        }

        if self.rebuild_extension() {
            self.print_status("Compiling extension", Self::build_extension)?;
        }

        self.print_status("Seeding database", Self::seed_database)?;
        self.print_status("Starting a3 server", Self::start_a3_server)?;
        self.print_status("Starting log stream", Self::stream_logs)?;
        // self.print_status("Starting a3 client", Self::start_a3_client)?; // If flag is set
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

    fn rebuild_extension(&self) -> bool {
        // Force? Forced true
        // Just building the extension? Forced true
        // Just building just the mod? Forced false
        // No force, no only? return true only if the files have changed
        (self.force || self.only != "mod")
            && (self.force
                || self.only == "extension"
                || has_directory_changed(&self.file_watcher, &self.local_git_path.join("arma"))
                || has_directory_changed(&self.file_watcher, &self.local_git_path.join("message")))
    }

    // The entire mod
    fn rebuild_mod(&self) -> bool {
        // Force? Forced true
        // Just building the mod? Forced true
        // Just building just the extension? Forced false
        // No force, no only? return true only if the files have changed
        (self.force || self.only != "extension")
            && (self.force
                || self.only == "mod"
                || has_directory_changed(&self.file_watcher, &self.local_git_path.join("@esm")))
    }

    // Single addon
    fn rebuild_addon(&self, addon: &str) -> bool {
        // Force? Forced true
        // Just building the mod? Forced true
        // Just building just the extension? Forced false
        // No force, no only? return true only if the files have changed
        (self.force || self.only != "extension")
            && (self.force
                || self.only == "mod"
                || has_directory_changed(
                    &self.file_watcher,
                    &self.local_git_path.join("@esm").join("addons").join(addon),
                ))
    }

    //////////////////////////////////////////////////////////////////
    /// Build steps below
    //////////////////////////////////////////////////////////////////
    fn kill_arma(&mut self) -> BuildResult {
        match self.os {
            BuildOS::Linux => {
                local_command("docker kill", vec!["arma-server"])?;
            }
            BuildOS::Windows => {
                self.send_to_receiver(Command::KillArma)?;
            }
        };

        Ok(())
    }

    fn prepare_directories(&mut self) -> BuildResult {
        ////////////////////
        // Local directories
        // Keeps the files around for viewing when building the extension by itself
        if self.rebuild_mod() {
            let esm_path = self.local_build_path.join("@esm");

            // Delete @esm and recreate it
            if esm_path.exists() {
                fs::remove_dir_all(&esm_path)?;
                fs::create_dir_all(&esm_path)?;
            }

            // Create @esm/addons
            let addons_path = esm_path.join("addons");
            if !addons_path.exists() {
                fs::create_dir_all(&addons_path)?;
            }
        }

        // Remove some build files
        let paths = vec![
            "@esm.zip",
            "windows.zip",
            "linux.zip",
            "esm.zip",
            ".esm-build-command",
            ".esm-build-command-result",
        ];

        for path in paths {
            let path = self.local_build_path.join(path);
            if path.exists() && path.is_file() {
                fs::remove_file(&path)?;
            }
        }

        /////////////////////
        // Remote directories
        match self.os {
            BuildOS::Windows => {
                lazy_static! {
                    static ref PROFILES_REGEX: Regex = Regex::new(r#"-profiles=(\w+)"#).unwrap();
                };

                let captures = PROFILES_REGEX.captures(&self.remote.server_args).unwrap();
                let profile_name = match captures.get(1) {
                    Some(n) => n.as_str(),
                    None => return Err(
                        "\"-profiles\" must be provided in the server args. This is required for log streaming"
                            .to_string()
                            .into(),
                    ),
                };

                let script = format!(
                    r#"
                        Remove-Item "{server_path}\{profile_name}\*.log" -ErrorAction SilentlyContinue;
                        Remove-Item "{server_path}\{profile_name}\*.rpt" -ErrorAction SilentlyContinue;
                        Remove-Item "{server_path}\{profile_name}\*.bidmp" -ErrorAction SilentlyContinue;
                        Remove-Item "{server_path}\{profile_name}\*.mdmp" -ErrorAction SilentlyContinue;

                        New-Item -Path "{build_path}\esm" -ItemType Directory;
                        New-Item -Path "{build_path}\@esm" -ItemType Directory;
                        New-Item -Path "{build_path}\@esm\addons" -ItemType Directory;
                        New-Item -Path "{server_path}\@esm" -ItemType Directory;
                        New-Item -Path "{server_path}\@esm\addons" -ItemType Directory;
                    "#,
                    build_path = self.remote_build_path_str(),
                    server_path = self.remote.server_path,
                    profile_name = profile_name
                );

                self.system_command(
                    System::new()
                        .command(script)
                        .add_detection("error", true)
                        .wait(),
                )?;
            }
            BuildOS::Linux => (),
        };

        Ok(())
    }

    fn prepare_to_build(&mut self) -> BuildResult {
        self.kill_arma()?;
        self.detect_first_build()?;
        self.prepare_directories()?;
        self.transfer_mikeros_tools()?;
        self.create_server_config()?;
        self.create_esm_key_file()?;
        Ok(())
    }

    fn transfer_mikeros_tools(&mut self) -> BuildResult {
        let mikero_path = self
            .local_git_path
            .join("tools")
            .join("pbo_tools")
            .join(self.os.to_string());

        Directory::transfer(self, mikero_path, self.remote_build_path().to_owned())
    }

    fn create_server_config(&mut self) -> BuildResult {
        #[derive(Debug, PartialEq, Serialize, Deserialize)]
        struct Config {
            connection_url: String,
            log_level: String,
            env: String,
            log_output: String,
        }

        let config = Config {
            connection_url: self.bot_host.clone(),
            log_level: self.log_level.to_string(),
            env: self.env.to_string(),
            log_output: "rpt".into(),
        };

        let config_yaml = serde_yaml::to_vec(&config)?;
        fs::write(
            self.local_build_path
                .join("config.yml")
                .to_string_lossy()
                .to_string(),
            config_yaml,
        )?;

        crate::File::transfer(
            self,
            self.local_build_path.to_owned(),
            self.remote_build_path().join("@esm"),
            "config.yml",
        )?;

        Ok(())
    }

    fn create_esm_key_file(&mut self) -> BuildResult {
        let mut connection = self.redis.get_connection()?;
        let mut last_key_received = String::new();

        // Moved to a thread so this can happen over and over again for testing purposes
        thread::spawn(move || loop {
            let key: Option<String> = redis::cmd("GET")
                .arg(REDIS_SERVER_KEY)
                .query(&mut connection)
                .unwrap();

            let Some(key) = key else {
                thread::sleep(Duration::from_millis(500));
                continue;
            };

            if key == last_key_received {
                thread::sleep(Duration::from_millis(500));
                continue;
            }

            write_lock(&crate::SERVER, |mut server| {
                server.send(Command::Key(key.to_owned()))?;
                Ok(true)
            })
            .unwrap();

            last_key_received = key.to_owned();
        });

        Ok(())
    }

    fn detect_first_build(&mut self) -> BuildResult {
        let extension_file_name = match self.arch {
            BuildArch::X32 => "esm",
            BuildArch::X64 => "esm_x64",
        };

        let mut files_to_check: Vec<String> = ADDONS
            .iter()
            .map(|addon| format!(r"addons\{addon}.pbo"))
            .collect();

        if matches!(self.env, BuildEnv::Test) {
            files_to_check.push(r"addons\esm_test.pbo".to_string());
        }

        let script = match self.os {
            BuildOS::Windows => {
                files_to_check.push(format!("{extension_file_name}.dll"));

                files_to_check
                    .iter()
                    .map(|path| {
                        format!(
                            r#"
                                if (![System.IO.File]::Exists("{server_path}\@esm\{path}")) {{
                                    return "rebuild";
                                }}
                            "#,
                            server_path = self.remote.server_path
                        )
                    })
                    .collect::<Vec<String>>()
                    .join("\n")
            }
            BuildOS::Linux => todo!(),
        };

        let result = self.system_command(
            System::new()
                .command(script)
                .add_detection("rebuild.*", false),
        )?;

        let Command::SystemResponse(result) = result else {
            return Err("Invalid response for System command. Must be Command::SystemResponse".to_string().into());
        };

        if result == *"rebuild" {
            // This may be a first build - build all the things!
            self.force = true;
        }

        Ok(())
    }

    fn build_extension(&mut self) -> BuildResult {
        // This will be read by the build script and inserted into the extension
        let extension_path = self.local_git_path.join("arma");
        let message_path = self.local_git_path.join("message");

        fs::write(
            extension_path
                .join(".build-sha")
                .to_string_lossy()
                .to_string(),
            git_sha_short().as_bytes(),
        )?;

        // Copy the extension and message code over to the remote host
        Directory::transfer(self, extension_path, self.remote_build_path().to_owned())?;
        Directory::transfer(self, message_path, self.remote_build_path().to_owned())?;

        match self.os {
            BuildOS::Windows => {
                let script = format!(
                    r#"
                        cd '{build_path}\arma';
                        rustup run stable-{build_target} cargo build --target {build_target} --release;

                        Copy-Item "{build_path}\arma\target\{build_target}\release\esm_arma.dll" -Destination "{build_path}\@esm\{file_name}.dll"
                    "#,
                    build_path = self.remote_build_path_str(),
                    build_target = self.extension_build_target,
                    file_name = match self.arch {
                        BuildArch::X32 => "esm",
                        BuildArch::X64 => "esm_x64",
                    }
                );

                self.system_command(
                    System::new()
                        .command(script)
                        .add_detection(r"error: .+", true)
                        .add_detection(r"warning", false),
                )?;
            }
            BuildOS::Linux => todo!(),
        }

        Ok(())
    }

    fn check_for_p_drive(&mut self) -> BuildResult {
        assert!(matches!(self.os, BuildOS::Windows));

        let script = r#"
            if (Get-PSDrive P -ErrorAction SilentlyContinue) {{
                "p_drive_mounted";
            }} else {{
                "p_drive_not_mounted";
            }}
        "#;

        let result = self.system_command(
            System::new()
                .command(script)
                .add_detection("p_drive_mounted", false),
        )?;

        // Continue building
        if let Command::SystemResponse(r) = result {
            if r == *"p_drive_mounted" {
                return Ok(());
            }
        } else {
            panic!("Invalid response for System command. Must be Command::SystemResponse");
        }

        // WorkDrive.exe will keep a window open that requires user input
        println!("{}", "paused\nWaiting for input...".yellow());
        println!("Please confirm Window's UAC and then press any key on the window that WorkDrive has opened");

        let script = format!(
            r#"
                Start-Process -Wait -FilePath "{build_path}\windows\WorkDrive.exe" -ArgumentList "/Mount";

                if (Get-PSDrive P -ErrorAction SilentlyContinue) {{
                    "p_drive_mounted";
                }} else {{
                    "p_drive_not_mounted";
                }}
            "#,
            build_path = self.remote_build_path_str(),
        );

        self.system_command(
            System::new()
                .command(script)
                .add_detection("p_drive_not_mounted", true),
        )?;
        Ok(())
    }

    fn compile_mod(&mut self) -> BuildResult {
        lazy_static! {
            static ref DIRECTORIES: Vec<&'static str> = vec!["optionals", "sql"];
            static ref FILES: Vec<&'static str> = vec!["Licenses.txt"];
        }

        // Set up all the paths needed
        let mod_path = self.local_git_path.join("@esm");
        let source_path = mod_path.join("addons");

        let mod_build_path = self.local_build_path.join("@esm");
        let addon_destination_path = mod_build_path.join("addons");

        let mut compiler = Compiler::new();
        compiler
            .source(&source_path.to_string_lossy())
            .destination(&addon_destination_path.to_string_lossy())
            .target(&self.os.to_string());

        crate::compile::bind_replacements(&mut compiler);
        compiler.compile()?;

        Directory::transfer(self, mod_build_path, self.remote_build_path().to_owned())?;

        Ok(())
    }

    fn build_mod(&mut self) -> BuildResult {
        self.compile_mod()?;

        match self.os {
            BuildOS::Linux => todo!(),
            BuildOS::Windows => {
                let mut extra_addons = vec![];
                if matches!(self.env, BuildEnv::Test) {
                    extra_addons.push("esm_test");
                }

                for addon in ADDONS.iter().chain(extra_addons.iter()) {
                    if !self.rebuild_addon(addon) {
                        continue;
                    }

                    // The "root" is what matters here. The root needs to be P: drive
                    let script = format!(
                        r#"
                            if ([System.IO.Directory]::Exists("P:\{addon}")) {{
                                Remove-Item -Path "P:\{addon}" -Recurse;
                            }}

                            Move-Item -Force -Path "{build_path}\@esm\addons\{addon}" -Destination "P:";
                            Start-Process -Wait -NoNewWindow -FilePath "{build_path}\windows\MakePbo.exe" -ArgumentList "-P", "P:\{addon}", "{build_path}\@esm\addons\{addon}.pbo";

                            if (!([System.IO.File]::Exists("{build_path}\@esm\addons\{addon}.pbo"))) {{
                                "Failed to build - {build_path}\@esm\addons\{addon}.pbo does not exist"
                            }}
                        "#,
                        build_path = self.remote_build_path_str(),
                    );

                    self.system_command(
                        System::new()
                            .command(script)
                            .add_detection("ErrorId", true)
                            .add_detection("Failed to build", true)
                            .add_detection("missing file", true),
                    )?;
                }
            }
        }

        Ok(())
    }

    fn seed_database(&mut self) -> BuildResult {
        let sql = Database::generate_sql(&self.config);
        match self.send_to_receiver(Command::Database(sql)) {
            Ok(_) => Ok(()),
            Err(e) => Err(e),
        }
    }

    fn start_a3_server(&mut self) -> BuildResult {
        match self.os {
            BuildOS::Windows => {
                let script = format!(
                    r#"
                        Remove-Item -Path "{server_path}\@esm" -Recurse;
                        Copy-Item -Path "{build_path}\@esm" -Destination "{server_path}\@esm" -Recurse;

                        Start-Process "{server_path}\{server_executable}" `
                            -ArgumentList "{server_args}" `
                            -WorkingDirectory "{server_path}";
                    "#,
                    build_path = self.remote_build_path_str(),
                    server_path = self.remote.server_path,
                    server_executable = match self.arch {
                        BuildArch::X32 => "arma3server.exe",
                        BuildArch::X64 => "arma3server_x64.exe",
                    },
                    server_args = self.remote.server_args
                );

                self.system_command(System::new().command(script))?;
            }
            BuildOS::Linux => todo!(),
        }

        Ok(())
    }

    // fn start_a3_client(&mut self) -> BuildResult {
    //     // client arg: client start args
    //     // Send command to receiver
    //     // Issue! In order to start the client on linux, both the linux machine and windows machine will need to be connected
    //     //          This will need to be solved.
    //     Ok(())
    // }

    fn stream_logs(&mut self) -> BuildResult {
        struct Highlight {
            pub regex: Regex,
            pub color: [u8; 3],
        }

        lazy_static! {
            static ref HIGHLIGHTS: Vec<Highlight> = vec![
                Highlight {
                    regex: Regex::new(r"ERROR\b").unwrap(),
                    color: [153, 0, 51]
                },
                Highlight {
                    regex: Regex::new(r"WARN").unwrap(),
                    color: [153, 102, 0]
                },
                Highlight {
                    regex: Regex::new(r"INFO").unwrap(),
                    color: [102, 204, 255]
                },
                Highlight {
                    regex: Regex::new(r"DEBUG").unwrap(),
                    color: [80, 82, 86]
                },
                Highlight {
                    regex: Regex::new(r"TRACE").unwrap(),
                    color: [255, 153, 102]
                }
            ];
        }

        self.send_to_receiver(Command::LogStreamInit)?;

        loop {
            let result = self.send_to_receiver(Command::LogStreamRequest)?;
            let lines = match result {
                Command::LogStream(l) => l,
                c => {
                    return Err(
                        format!("Invalid response to LogStreamRequest. Received {:?}", c).into(),
                    )
                }
            };

            for line in lines {
                let content = line.content.trim_end();
                let extension = Path::new(&line.filename)
                    .extension()
                    .unwrap()
                    .to_string_lossy()
                    .to_string();

                let highlight = HIGHLIGHTS.iter().find(|h| h.regex.is_match(content));

                println!(
                    "{name}:{line_number:5}{sep} {content}",
                    sep = "|".bright_black(),
                    name = extension.truecolor(line.color[0], line.color[1], line.color[2]),
                    line_number = line.line_number.to_string().bright_black(),
                    content = if let Some(h) = highlight {
                        content.bold().truecolor(h.color[0], h.color[1], h.color[2])
                    } else {
                        content.normal()
                    }
                )
            }
        }
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

fn git_sha_short() -> String {
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
