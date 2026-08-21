use std::{
    fmt,
    path::{Path, PathBuf},
    sync::Arc,
};

use crate::{
    config::{parse, Config, Instance},
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

    /// Start the server and nothing else: no build, no deploy, no database work.
    ///
    /// Every file on the server is left exactly as it is, which is what makes it useful for testing something
    /// staged by hand. A normal start redeploys @esm, and that would put back the config.yml and version records
    /// the test just set up.
    #[arg(long)]
    start_only: bool,

    /// Which server to run, by its ESM server_id (see `instances` in config.yml). Defaults to the first entry.
    #[arg(long)]
    server_id: Option<String>,

    /// Run every server declared under `instances` in config.yml
    #[arg(long)]
    all: bool,

    /// Builds with the production environment (no development feature flag)
    #[arg(short, long)]
    pub release: bool,

    /// Path to the esm.key file to use (useful with --release --start-server)
    #[arg(short, long, default_value_t = String::new())]
    key_file: String,

    /// Seed the near-due showcase territories as un-notified so Exile fires
    /// their protection-money XM8 notifications once on start (default: seeded
    /// already-notified, so a routine dev start stays quiet)
    #[arg(long)]
    pub seed_xm8_notify: bool,
}

impl Args {
    pub fn build_arch(&self) -> BuildArch {
        if self.x32 {
            BuildArch::X32
        } else {
            BuildArch::X64
        }
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

    /// Whether this run ends with a running server.
    ///
    /// `--start-only` implies it: skipping the build is about what happens on the way there, not about whether the
    /// server comes up at the end.
    pub fn start_server(&self) -> bool {
        self.start_server || self.start_only
    }

    pub fn start_only(&self) -> bool {
        self.start_only
    }

    pub fn has_key_file(&self) -> bool {
        !self.key_file.is_empty() && self.key_file_path().exists()
    }

    pub fn key_file_path(&self) -> PathBuf {
        PathBuf::from(&self.key_file)
    }

    pub fn all_instances(&self) -> bool {
        self.all
    }

    pub fn server_id(&self) -> Option<&str> {
        self.server_id.as_deref()
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

/// State shared by the whole run. The mod and the extension are built once no matter how many servers are
/// started, so everything here is deliberately singular; anything that varies per server lives on
/// [`InstanceContext`].
pub struct BuildContext {
    pub args: Args,
    pub config: Config,
    pub git_path: PathBuf,
    /// Local Rust `target/` directory
    pub local_build_path: PathBuf,
    pub file_watcher: FileWatcher,
    pub rebuild_mod: bool,
    pub rebuild_extension: bool,
    /// Servers this run targets, resolved from `--server-id` / `--all`. Never empty.
    pub instances: Vec<Instance>,
}

impl BuildContext {
    pub fn new(args: Args) -> Result<Self, BuildError> {
        let git_path = find_git_root()?;
        let local_build_path = git_path.join("target");
        let config = parse(&git_path.join("config.yml"))?;
        let instances = select_instances(&args, &config)?;

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
            git_path,
            local_build_path,
            file_watcher,
            rebuild_mod,
            rebuild_extension,
            instances,
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

    pub fn extension_build_target(&self) -> &'static str {
        match (self.args.build_os(), self.args.build_arch()) {
            (BuildOS::Linux, BuildArch::X32) => "i686-unknown-linux-gnu",
            (BuildOS::Linux, BuildArch::X64) => "x86_64-unknown-linux-gnu",
            (BuildOS::Windows, BuildArch::X32) => "i686-pc-windows-gnu",
            (BuildOS::Windows, BuildArch::X64) => "x86_64-pc-windows-gnu",
        }
    }
}

/// One server's slice of a run: which server it is, and how to reach the container holding it.
///
/// Paths *inside* the container are identical for every server, so the target it carries differs only in which
/// container it execs into and which game port it launches with.
pub struct InstanceContext<'a> {
    pub build: &'a BuildContext,
    pub instance: &'a Instance,
    pub target: Arc<dyn Target>,
}

impl<'a> InstanceContext<'a> {
    pub fn new(build: &'a BuildContext, instance: &'a Instance) -> Result<Self, BuildError> {
        let target = build_target(&build.args, &build.config, instance)?;
        Ok(InstanceContext {
            build,
            instance,
            target,
        })
    }

    pub fn args(&self) -> &Args {
        &self.build.args
    }

    pub fn config(&self) -> &Config {
        &self.build.config
    }

    pub fn container(&self) -> String {
        self.instance.container()
    }

    pub fn server_path(&self) -> &Path {
        self.target.server_path()
    }

    /// Address to write into `extdb3-conf.ini`, or `None` to leave the shipped one alone.
    ///
    /// Only the Windows target overrides it. A container resolves `mysql_db` through Docker's DNS and so needs
    /// no help; anything outside that network cannot resolve it at all.
    pub fn database_host(&self) -> Option<&str> {
        match self.args().build_os() {
            BuildOS::Linux => None,
            BuildOS::Windows => self
                .config()
                .windows
                .as_ref()
                .and_then(|windows| windows.database_host.as_deref()),
        }
    }

    /// Whether this is the first server in config.yml, which is the one a bare `bin/build --start-server`
    /// runs and the one that answers for the unnamespaced Redis key slot.
    pub fn is_default_instance(&self) -> bool {
        self.build
            .config
            .instances
            .first()
            .is_some_and(|first| first.server_id == self.instance.server_id)
    }

    /// Staging directory for artefacts belonging to this server alone, as opposed to the shared `target/@esm`
    /// tree that every server deploys from.
    pub fn instance_staging_path(&self) -> PathBuf {
        self.build
            .local_build_path
            .join("instances")
            .join(&self.instance.server_id)
    }
}

/// Resolve `--server-id` / `--all` against the configured servers.
fn select_instances(args: &Args, config: &Config) -> Result<Vec<Instance>, BuildError> {
    if args.all_instances() {
        if args.has_key_file() {
            return Err(BuildError::Config(
                "--key-file applies to a single server, so it cannot be combined with --all. Pass \
                 --server-id to name the one server the key belongs to."
                    .into(),
            ));
        }

        return Ok(config.instances.clone());
    }

    // `parse` rejects an empty list, so the first entry is always there to fall back on.
    let Some(server_id) = args.server_id() else {
        return Ok(vec![config.instances[0].clone()]);
    };

    config
        .instances
        .iter()
        .find(|instance| instance.server_id == server_id)
        .map(|instance| vec![instance.clone()])
        .ok_or_else(|| {
            let configured: Vec<&str> = config
                .instances
                .iter()
                .map(|instance| instance.server_id.as_str())
                .collect();

            BuildError::Config(format!(
                "No server with server_id '{server_id}' in config.yml. Configured: {}.",
                configured.join(", ")
            ))
        })
}

fn find_git_root() -> Result<PathBuf, BuildError> {
    let mut dir =
        std::env::current_dir().map_err(|e| BuildError::General(e.to_string()))?;

    loop {
        if dir.join(".git").is_dir() {
            return Ok(dir.join("arma"));
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
