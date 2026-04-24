use std::{
    fmt,
    path::{Path, PathBuf},
};

use crate::{
    config::{parse, Config},
    error::BuildError,
    file_watcher::FileWatcher,
    target::{build_target, Target},
};

use clap::{Parser, ValueEnum};

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum, Debug)]
pub enum BuildOS {
    Linux,
    Windows,
}

impl fmt::Display for BuildOS {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", format!("{self:?}").to_lowercase())
    }
}

#[derive(Debug, Copy, Clone)]
pub enum BuildArch {
    X32,
    X64,
}

pub fn git_sha_short() -> String {
    use std::process::Command;

    let output = Command::new("git")
        .args(["rev-parse", "--short", "HEAD"])
        .output();

    match output {
        Ok(o) if o.status.success() => {
            String::from_utf8_lossy(&o.stdout).trim().to_string()
        }
        _ => "FAILED".into(),
    }
}

/// Builds ESM's Arma 3 server mod
#[derive(Parser, Debug)]
#[command(name = "bin/build")]
#[command(bin_name = "bin/build")]
#[command(author, version, about, long_about = None)]
pub struct Args {
    /// Build the extension as 32-bit instead of 64-bit
    #[arg(short, long)]
    x32: bool,

    /// Set the target build platform for the extension
    #[arg(short, long, value_enum, default_value_t = BuildOS::Linux)]
    target: BuildOS,

    /// Sets the logging level for the extension and the mod
    #[arg(short, long, value_enum, default_value_t = LogLevel::Debug)]
    log_level: LogLevel,

    /// The URI of the server hosting esm_bot
    #[arg(long, default_value_t = String::from("host.docker.internal:3003"))]
    bot_host: String,

    /// Forces a full rebuild of everything
    #[arg(short, long)]
    full: bool,

    /// Build only one component: mod or extension
    #[arg(short, long, value_parser = ["mod", "extension"])]
    only: Option<String>,

    /// Updates the Arma server via steamcmd (linux target only)
    #[arg(short, long)]
    update: bool,

    /// Builds the code and starts the server after building
    #[arg(short, long)]
    start_server: bool,

    /// Builds with the production environment (no development feature flag)
    #[arg(short, long)]
    pub release: bool,

    /// Path to the esm.key file to use (useful with --release --start-server)
    #[arg(short, long, default_value_t = String::new())]
    key_file: String,
}

impl Args {
    pub fn build_arch(&self) -> BuildArch {
        if self.x32 { BuildArch::X32 } else { BuildArch::X64 }
    }

    pub fn build_os(&self) -> BuildOS {
        self.target
    }

    pub fn only_build(&self) -> &str {
        match &self.only {
            Some(v) => v,
            None => "",
        }
    }

    pub fn log_level(&self) -> LogLevel {
        self.log_level
    }

    pub fn bot_host(&self) -> &str {
        &self.bot_host
    }

    pub fn full_rebuild(&self) -> bool {
        self.full
    }

    pub fn update_arma(&self) -> bool {
        self.update
    }

    pub fn start_server(&self) -> bool {
        self.start_server
    }

    pub fn has_key_file(&self) -> bool {
        !self.key_file.is_empty() && self.key_file_path().exists()
    }

    pub fn key_file_path(&self) -> PathBuf {
        PathBuf::from(&self.key_file)
    }
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum, Debug)]
pub enum LogLevel {
    Error,
    Warn,
    Info,
    Debug,
    Trace,
}

impl fmt::Display for LogLevel {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", format!("{self:?}").to_lowercase())
    }
}

/// Central state for the entire build run.
pub struct BuildContext {
    pub args: Args,
    pub config: Config,
    pub target: Box<dyn Target>,
    pub git_path: PathBuf,
    /// Local Rust `target/` directory
    pub local_build_path: PathBuf,
    pub file_watcher: FileWatcher,
    pub rebuild_mod: bool,
    pub rebuild_extension: bool,
}

impl BuildContext {
    pub fn new(args: Args) -> Result<Self, BuildError> {
        let git_path = find_git_root()?;
        let local_build_path = git_path.join("target");
        let config = parse(&git_path.join("config.yml"))?;
        let target = build_target(&args, &config)?;

        let file_watcher = FileWatcher::new(&git_path, &local_build_path)
            .watch(&git_path.join("src").join("@esm"))
            .watch(&git_path.join("src").join("esm"))
            .watch(&git_path.join("src").join("updater"))
            .watch(&git_path.join("src").join("message"))
            .watch(&git_path.join("src").join("build").join("compiler"))
            .ignore(&git_path.join("src").join("esm").join(".build-sha"))
            .load()?;

        let rebuild_mod = args.full_rebuild();
        let rebuild_extension = args.full_rebuild();

        Ok(BuildContext {
            args,
            config,
            target,
            git_path,
            local_build_path,
            file_watcher,
            rebuild_mod,
            rebuild_extension,
        })
    }

    pub fn rebuild_mod(&self) -> bool {
        if self.args.only_build() == "extension" {
            return false;
        }

        self.args.release
            || self.rebuild_mod
            || self.args.only_build() == "mod"
            || has_directory_changed(
                &self.file_watcher,
                &self.git_path.join("src").join("@esm"),
            )
    }

    pub fn rebuild_extension(&self) -> bool {
        if self.args.only_build() == "mod" {
            return false;
        }

        self.args.release
            || self.rebuild_extension
            || self.args.only_build() == "extension"
            || has_directory_changed(
                &self.file_watcher,
                &self.git_path.join("src").join("esm"),
            )
            || has_directory_changed(
                &self.file_watcher,
                &self.git_path.join("src").join("updater"),
            )
            || has_directory_changed(
                &self.file_watcher,
                &self.git_path.join("src").join("message"),
            )
    }

    pub fn rebuild_addon(&self, addon: &str) -> bool {
        if self.args.only_build() == "extension" {
            return false;
        }

        self.rebuild_mod
            || self.args.only_build() == "mod"
            || has_directory_changed(
                &self.file_watcher,
                &self.git_path
                    .join("src")
                    .join("@esm")
                    .join("addons")
                    .join(addon),
            )
    }

    pub fn extension_build_target(&self) -> &'static str {
        match (self.args.build_os(), self.args.build_arch()) {
            (BuildOS::Linux, BuildArch::X32) => "i686-unknown-linux-gnu",
            (BuildOS::Linux, BuildArch::X64) => "x86_64-unknown-linux-gnu",
            (BuildOS::Windows, BuildArch::X32) => panic!(
                "--x32 --target=windows is not supported from Linux: \
                 build it on a Windows host instead."
            ),
            (BuildOS::Windows, BuildArch::X64) => "x86_64-pc-windows-gnu",
        }
    }
}

fn find_git_root() -> Result<PathBuf, BuildError> {
    let mut dir = std::env::current_dir()
        .map_err(|e| BuildError::General(e.to_string()))?;

    loop {
        if dir.join(".git").is_dir() {
            return Ok(dir);
        }
        if !dir.pop() {
            return Err(BuildError::General(
                "Could not find git repository root".into(),
            ));
        }
    }
}

pub fn has_directory_changed(watcher: &FileWatcher, path: &Path) -> bool {
    let file_paths = match glob::glob(&format!("{}/**/*", path.display())) {
        Ok(p) => p,
        Err(_) => return true,
    };

    file_paths
        .filter_map(|p| p.ok())
        .any(|p| watcher.was_modified(&p))
}
