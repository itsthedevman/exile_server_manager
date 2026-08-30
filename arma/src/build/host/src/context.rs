use std::{
    fmt,
    path::{Path, PathBuf},
    sync::Arc,
};

use crate::{
    config::{parse, Config, Instance, WindowsConfig},
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
    #[command(subcommand)]
    command: Option<Command>,

    /// Build the extension as 32-bit instead of 64-bit
    #[arg(short, long)]
    x32: bool,

    /// Set the target build platform for the extension
    ///
    /// Global so that it reads the same before or after a subcommand: staging a Windows guest and building for
    /// one are the same `--target=windows`, and a flag that only worked in one position would be a trap.
    #[arg(short, long, value_enum, default_value_t = BuildOS::Linux, global = true)]
    target: BuildOS,

    /// Sets the logging level for the extension and the mod
    #[arg(short, long, value_enum, default_value_t = LogLevel::Debug)]
    log_level: LogLevel,

    /// The URI of the server hosting esm_bot. Defaults per target; see `InstanceContext::bot_host`.
    #[arg(long)]
    bot_host: Option<String>,

    /// Manifest the updater checks on boot, written into the deployed `@esm/config.yml` as `updater_url`.
    ///
    /// A deploy renders that file from scratch, so a URL staged into the previous one is gone by the time the
    /// server next boots. Naming it here is what points the boot-time check at a local manifest server for the
    /// length of a test, rather than at the release host, whose answer on a dev box is a 404 and a study of the
    /// fail-open path.
    #[arg(long)]
    updater_url: Option<String>,

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
    #[arg(long, global = true)]
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

#[derive(clap::Subcommand, Debug)]
pub enum Command {
    /// Put one server's @esm into a known starting position for an updater test
    Stage(StageArgs),
}

/// Where a server's installed-version record should be left before an updater run.
///
/// Every component defaults to the version the current source would install, so naming one flag moves one thing
/// and leaves the rest reading as already up to date. A version of `none` drops that component's entry entirely,
/// which the updater reads as 0.0.0 rather than as a missing record.
#[derive(clap::Args, Debug)]
pub struct StageArgs {
    /// Version to record for the extension
    #[arg(long)]
    pub esm: Option<String>,

    /// Version to record for the mod
    #[arg(long = "mod")]
    pub server_mod: Option<String>,

    /// Version to record for the updater extension
    #[arg(long)]
    pub updater_ext: Option<String>,

    /// Version to record for the updater mod
    #[arg(long)]
    pub updater_mod: Option<String>,

    /// Strip @esm back to what a first-time install starts from, keeping esm.key and config.yml
    ///
    /// Flips the default for every unnamed component to `none`, since an install that has never run the updater
    /// has no record of anything.
    #[arg(long)]
    pub wipe: bool,

    /// Install the updater CLI into @esm/bin, which a build never deploys
    #[arg(long)]
    pub cli: bool,
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

    /// The subcommand this run is, or `None` for a build.
    pub fn command(&self) -> Option<&Command> {
        self.command.as_ref()
    }

    /// `--bot-host` as given, or `None` to let the target decide.
    pub fn bot_host(&self) -> Option<&str> {
        self.bot_host.as_deref()
    }

    /// `--updater-url` as given, or `None` to leave the key out of the deployed config and let the updater fall
    /// back to the release host it was built against.
    pub fn updater_url(&self) -> Option<&str> {
        self.updater_url.as_deref()
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
/// Where a container reaches the machine running the bot. Docker resolves it; nothing else does.
const DEFAULT_BOT_HOST: &str = "host.docker.internal:3003";

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

    /// Address to write into the deployed `@esm/config.yml` as `connection_uri`.
    ///
    /// `host.docker.internal` is a Docker invention and resolves only inside a container, so it is the right
    /// default for the Linux target and useless on any other host. A Windows guest names the bot's address in
    /// `windows.bot_host` instead. An explicit `--bot-host` outranks both.
    pub fn bot_host(&self) -> &str {
        if let Some(host) = self.args().bot_host() {
            return host;
        }

        match self.args().build_os() {
            BuildOS::Linux => DEFAULT_BOT_HOST,
            BuildOS::Windows => self
                .config()
                .windows
                .as_ref()
                .and_then(|windows| windows.bot_host.as_deref())
                .unwrap_or(DEFAULT_BOT_HOST),
        }
    }

    /// Where a game client reaches this server, as `host:port`.
    ///
    /// This is the address Steam queries and players connect to, which is not something anything else here
    /// needs: the bot is reached over TCP the extension opens itself, and the database over a connection string.
    /// Only a client talking straight to the game port cares, and the only one of those in this project is the
    /// A2S spec.
    pub fn game_address(&self) -> String {
        game_address(
            self.args().build_os(),
            self.config().windows.as_ref(),
            self.instance.port,
        )
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

/// Where a game client reaches a server, given the target it was built for.
///
/// A container publishes its ports onto the machine running the build, so `127.0.0.1` reaches it and no config
/// can say otherwise. Anywhere else the address has to be named, and `game_host` is what names it; falling back
/// to `host` keeps the common case (one literal address, used for both SSH and the game) free of a second key
/// that would only ever repeat the first.
fn game_address(os: BuildOS, windows: Option<&WindowsConfig>, port: u16) -> String {
    let host = match os {
        BuildOS::Linux => "127.0.0.1",
        BuildOS::Windows => windows
            .map(|windows| windows.game_host.as_deref().unwrap_or(&windows.host))
            .unwrap_or("127.0.0.1"),
    };

    format!("{host}:{port}")
}

/// Resolve `--server-id` / `--all` against the configured servers.
pub fn select_instances(args: &Args, config: &Config) -> Result<Vec<Instance>, BuildError> {
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

pub fn find_git_root() -> Result<PathBuf, BuildError> {
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

#[cfg(test)]
mod tests {
    use super::*;

    fn windows(host: &str, game_host: Option<&str>) -> WindowsConfig {
        WindowsConfig {
            host: host.to_string(),
            user: "Administrator".to_string(),
            server_path: "C:\\arma3server".to_string(),
            steamcmd_path: "C:\\steamcmd".to_string(),
            database_host: None,
            bot_host: None,
            game_host: game_host.map(|host| host.to_string()),
            server_args: vec![],
        }
    }

    #[test]
    fn a_container_publishes_onto_the_build_machine() {
        let config = windows("winvm", Some("10.0.0.2"));
        assert_eq!(game_address(BuildOS::Linux, Some(&config), 2302), "127.0.0.1:2302");
    }

    #[test]
    fn game_host_wins_over_the_ssh_target() {
        let config = windows("winvm", Some("10.0.0.2"));
        assert_eq!(game_address(BuildOS::Windows, Some(&config), 2302), "10.0.0.2:2302");
    }

    #[test]
    fn host_stands_in_while_it_is_still_an_address() {
        let config = windows("10.0.0.2", None);
        assert_eq!(game_address(BuildOS::Windows, Some(&config), 2302), "10.0.0.2:2302");
    }
}
