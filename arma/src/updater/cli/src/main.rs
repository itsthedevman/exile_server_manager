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
use std::time::{Duration, Instant};

// ---------------------------------------------------------------------------
// CLI argument structures
// ---------------------------------------------------------------------------

/// ESM update tool.
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
    /// Exits with code 0 if everything is up-to-date, or 2 if updates are
    /// available.
    Check {
        /// Override the manifest URL (useful for staging).
        #[arg(long)]
        manifest_url: Option<String>,

        /// Change working directory before running (server root).
        #[arg(long)]
        server_root: Option<String>,
    },

    /// Download and apply updates.
    Update {
        /// Which component to update.
        #[arg(default_value = "all")]
        target: UpdateTarget,

        /// Override the manifest URL.
        #[arg(long)]
        manifest_url: Option<String>,

        /// Change working directory before running.
        #[arg(long)]
        server_root: Option<String>,
    },

    /// Download and apply all updates (alias for `update all`).
    Install {
        /// Override the manifest URL.
        #[arg(long)]
        manifest_url: Option<String>,

        /// Change working directory before running.
        #[arg(long)]
        server_root: Option<String>,
    },

    /// Print the updater version and exit.
    Version,
}

/// Component selection for the `update` subcommand.
#[derive(Clone, ValueEnum)]
enum UpdateTarget {
    All,
    Extension,
    Mod,
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

fn main() {
    env_logger::init();
    let cli = Cli::parse();

    let exit_code = match run(cli) {
        Ok(code) => code,
        Err(e) => {
            error!("{e}");
            1
        }
    };

    std::process::exit(exit_code);
}

/// Returns exit code: 0 = ok, 1 = error, 2 = updates available (check only).
fn run(cli: Cli) -> Result<i32, Box<dyn std::error::Error>> {
    match cli.command {
        Commands::Version => {
            println!("{}", env!("CARGO_PKG_VERSION"));
            Ok(0)
        }

        Commands::Check { manifest_url, server_root } => {
            if let Some(root) = server_root {
                std::env::set_current_dir(&root)?;
            }

            let deadline =
                Instant::now() + Duration::from_millis(800);
            let result = Updater::run_boot_check(deadline)?;
            let status = result.to_status_string();
            println!("{status}");

            let updates_available = status.starts_with("updated")
                || status.starts_with("pending");
            let _ = manifest_url; // boot_check uses config; URL not exposed here
            Ok(if updates_available { 2 } else { 0 })
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
                Updater::run_cli_update(selection, manifest_url)?;
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
            let updated =
                Updater::run_cli_update(UpdateSelection::All, manifest_url)?;
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
