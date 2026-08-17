#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)]
#![cfg_attr(test, allow(clippy::unwrap_used, clippy::expect_used))]

//! `esm_updater` — CLI for checking and applying ESM updates.
//!
//! Subcommands:
//! - `check`   — print update summary, exit 0 (none) or 2 (updates available).
//! - `update`  — download and apply updates; target defaults to `all`.
//! - `install` — alias for `update all`.
//! - `version` — print the binary version.

use clap::{Parser, Subcommand, ValueEnum};
use log::{error, info};
use updater_lib::{UpdateSelection, Updater};

// ---------------------------------------------------------------------------
// CLI argument structures
// ---------------------------------------------------------------------------

/// Keeps an Arma 3 server's ESM install up to date.
///
/// Your server already checks for a new extension by itself each time it boots. This tool covers what that check
/// does not: the @esm mod files, the updater's own components, and updating on demand instead of waiting for a
/// restart.
///
/// Run it from your server folder, the one containing @esm.
#[derive(Parser)]
#[command(name = "esm_updater", version = env!("CARGO_PKG_VERSION"))]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

/// Available subcommands.
#[derive(Subcommand)]
enum Commands {
    /// Check for available updates without installing.
    ///
    /// Reads only: nothing is downloaded and nothing on disk is modified.
    /// Exits with code 0 if everything is up-to-date, or 2 if updates are
    /// available.
    Check {
        /// Use a different update source. Rarely needed outside testing.
        #[arg(long)]
        manifest_url: Option<String>,

        /// Run against a different server folder instead of the one you are in.
        ///
        /// Useful if you stage updates somewhere separate and copy them to your server yourself.
        #[arg(long)]
        server_root: Option<String>,
    },

    /// Download and install updates.
    ///
    /// Stop your server first. Every file is checked against a signature and a checksum before anything is
    /// replaced, and a file that fails either check is left alone.
    Update {
        /// Which part of ESM to update.
        #[arg(default_value = "all")]
        target: UpdateTarget,

        /// Use a different update source. Rarely needed outside testing.
        #[arg(long)]
        manifest_url: Option<String>,

        /// Run against a different server folder instead of the one you are in.
        ///
        /// Useful if you stage updates somewhere separate and copy them to your server yourself.
        #[arg(long)]
        server_root: Option<String>,
    },

    /// Download and apply all updates (alias for `update all`).
    Install {
        /// Use a different update source. Rarely needed outside testing.
        #[arg(long)]
        manifest_url: Option<String>,

        /// Run against a different server folder instead of the one you are in.
        ///
        /// Useful if you stage updates somewhere separate and copy them to your server yourself.
        #[arg(long)]
        server_root: Option<String>,
    },

    /// Print the updater version and exit.
    Version,
}

/// Component selection for the `update` subcommand.
#[derive(Clone, ValueEnum)]
enum UpdateTarget {
    /// Everything this server has an update available for.
    All,
    /// The ESM extension only, which your server also updates by itself while it boots.
    Extension,
    /// The @esm mod files only.
    Mod,
    /// The updater's own components only.
    Updater,
}

impl From<UpdateTarget> for UpdateSelection {
    fn from(t: UpdateTarget) -> Self {
        match t {
            UpdateTarget::All => UpdateSelection::All,
            UpdateTarget::Extension => UpdateSelection::Extension,
            UpdateTarget::Mod => UpdateSelection::Mod,
            UpdateTarget::Updater => UpdateSelection::Updater,
        }
    }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

/// Say so when this build verifies against something other than the default key.
///
/// Such a build refuses official releases outright, which looks identical to the updater being broken. The warning
/// is what separates the two. A default build stays quiet, since saying so every run is just noise.
fn warn_on_custom_key() {
    if updater_lib::USES_DEFAULT_KEY {
        return;
    }

    eprintln!(
        "warning: this updater verifies against a {}.",
        updater_lib::verification_key_label()
    );
    eprintln!("         It will not accept official ESM releases. Use an official build on a live server.");
}

fn main() {
    env_logger::init();

    // After parsing, so `--help` and `--version` stay clean.
    let cli = Cli::parse();
    warn_on_custom_key();

    let exit_code = match run(cli) {
        Ok(code) => code,
        Err(e) => {
            error!("{e}");
            1
        }
    };

    std::process::exit(exit_code);
}

/// This binary's own version.
///
/// Unlike the components it installs, the CLI genuinely can ask itself: it is the running process, so its crate
/// version is the right answer rather than a stand-in for one. An unparseable version falls back to `0.0.0`, which
/// reads as "ancient" and errs toward telling the operator to update.
fn running_version() -> semver::Version {
    semver::Version::parse(env!("CARGO_PKG_VERSION"))
        .unwrap_or_else(|_| semver::Version::new(0, 0, 0))
}

/// Tell the operator when they are driving an updater older than the manifest expects.
///
/// Nothing is replaced. Swapping the binary that is mid-update is the operator's call, and a wrong version is worth
/// knowing about precisely because it changes how everything else gets installed.
fn warn_if_stale(newer: Option<&semver::Version>) {
    let Some(newer) = newer else { return };

    eprintln!(
        "warning: this updater is {}, but {newer} is available.",
        running_version()
    );
    eprintln!("         Download the newer updater before installing anything else.");
}

/// Returns exit code: 0 = ok, 1 = error, 2 = updates available (check only).
fn run(cli: Cli) -> Result<i32, Box<dyn std::error::Error>> {
    match cli.command {
        Commands::Version => {
            // The key is named here as well as warned about, so the release tooling can compare what a package was
            // built against with what is about to sign for it, and so a support request carries both facts at once.
            println!(
                "{} ({})",
                env!("CARGO_PKG_VERSION"),
                updater_lib::verification_key_label()
            );
            Ok(0)
        }

        Commands::Check { manifest_url, server_root } => {
            if let Some(root) = server_root {
                std::env::set_current_dir(&root)?;
            }

            let outcome = Updater::run_check(manifest_url, &running_version())?;

            warn_if_stale(outcome.newer_cli.as_ref());

            if outcome.available.is_empty() {
                println!("Everything is up to date.");
                return Ok(0);
            }

            for update in &outcome.available {
                match &update.blocked_by {
                    Some(requirement) => println!(
                        "{}: {} -> {} (blocked, needs {requirement})",
                        update.name, update.installed, update.available
                    ),
                    None => println!(
                        "{}: {} -> {}",
                        update.name, update.installed, update.available
                    ),
                }
            }

            Ok(2)
        }

        Commands::Update {
            target,
            manifest_url,
            server_root,
        } => {
            if let Some(root) = server_root {
                std::env::set_current_dir(&root)?;
            }
            let selection: UpdateSelection = target.into();
            let updated =
                Updater::run_cli_update(selection, manifest_url, &running_version())?;
            for comp in &updated {
                info!(
                    "[update] {} | total={}ms",
                    comp.name, comp.elapsed_ms
                );
                println!(
                    "Updated {} to {}  ({}ms)",
                    comp.name, comp.version, comp.elapsed_ms
                );
            }
            if updated.is_empty() {
                println!("Nothing to update.");
            }
            Ok(0)
        }

        Commands::Install { manifest_url, server_root } => {
            if let Some(root) = server_root {
                std::env::set_current_dir(&root)?;
            }
            let updated = Updater::run_cli_update(
                UpdateSelection::All,
                manifest_url,
                &running_version(),
            )?;
            for comp in &updated {
                info!(
                    "[update] {} | total={}ms",
                    comp.name, comp.elapsed_ms
                );
                println!(
                    "Updated {} to {}  ({}ms)",
                    comp.name, comp.version, comp.elapsed_ms
                );
            }
            if updated.is_empty() {
                println!("Nothing to update.");
            }
            Ok(0)
        }
    }
}
