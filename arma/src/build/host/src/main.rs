// Most of this code was from the example, thank you!
// https://github.com/lemunozm/message-io/tree/master/examples/file-transfer

mod build_steps;
mod builder;
mod compile;
mod config;
mod database;
mod directory;
mod file;
mod file_watcher;
mod server;
mod string_table;

pub use build_steps::*;
pub use builder::*;
pub use common::*;
pub use compile::*;
pub use config::*;
pub use database::*;
pub use directory::*;
pub use file::*;
pub use file_watcher::*;
pub use server::*;

use std::{
    fmt::{self, Display},
    process::exit,
    sync::atomic::{AtomicBool, Ordering},
};

use clap::{Parser, ValueEnum};
use colored::Colorize;
use lazy_static::lazy_static;
pub use std::process::Command as SystemCommand;

lazy_static! {
    pub static ref CTRL_C_RECEIVED: AtomicBool = AtomicBool::new(false);
}

pub const REDIS_SERVER_KEY: &str = "server_key";
pub const REDIS_SERVER_KEY_CONFIRM: &str = "server_key_set";

pub const ADDONS: &[&str] = &[
    "exile_server_manager",
    "exile_server_overwrites",
    "exile_server_xm8",
    "exile_server_hacking",
    "exile_server_grinding",
    "exile_server_charge_plant_started",
    "exile_server_flag_steal_started",
    "exile_server_player_connected",
];

pub const ARMA_CONTAINER: &str = "ESM_ARMA_SERVER";
pub const ARMA_SERVICE: &str = "arma_server";
pub const ARMA_PATH: &str = "/arma3server";

pub const WINDOWS_EXES: &[&str] = &[
    "arma3server",
    "arma3server_x64",
    "arma3_x64",
    "arma3",
    "arma3battleye",
];

pub const LINUX_EXES: &[&str] =
    &["/arma3server/arma3server", "/arma3server/arma3server_x64"];

/// Builds ESM's Arma 3 server mod
#[derive(Parser, Debug)]
#[command(name = "bin/build")]
#[command(bin_name = "bin/build")]
#[command(author, version, about, long_about = None)]
pub struct Args {
    /// Build the extension as 32 bit instead of 64 bit
    #[arg(short, long)]
    x32: bool,

    /// Set the target build platform for the extension
    #[arg(short, long, value_enum, default_value_t = BuildOS::Linux)]
    target: BuildOS,

    /// Sets the logging level for the extension and the mod
    #[arg(short, long, value_enum, default_value_t = LogLevel::Debug)]
    log_level: LogLevel,

    /// Sets the logging level for the extension and the mod
    #[arg(short, long, value_enum, default_value_t = BuildEnv::Development)]
    env: BuildEnv,

    /// The URI of the server hosting esm_bot
    #[arg(long, default_value_t = String::from("192.168.50.242:3003"))]
    bot_host: String,

    /// Forces a full rebuild of everything
    #[arg(short, long)]
    full: bool,

    /// Space or comma separated list that controls which pieces are built
    #[arg(short, long, value_parser = ["mod", "extension"])]
    only: Option<String>,

    /// Updates Arma server (linux target only)
    #[arg(short, long)]
    update: bool,

    /// Builds the code and starts the server
    #[arg(short, long)]
    start_server: bool,

    // Builds everything and copies it to the release directory
    #[arg(short, long)]
    release: bool,
}

impl Args {
    pub fn build_arch(&self) -> BuildArch {
        if self.x32 {
            BuildArch::X32
        } else {
            BuildArch::X64
        }
    }

    pub fn build_env(&self) -> BuildEnv {
        self.env
    }

    pub fn build_os(&self) -> BuildOS {
        self.target
    }

    /// Controls which code group (extension, mod) is built for this run
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
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum, Debug)]
pub enum BuildOS {
    Linux,
    Windows,
}

impl Display for BuildOS {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", format!("{:?}", self).to_lowercase())
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
        write!(f, "{}", format!("{:?}", self).to_lowercase())
    }
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ValueEnum, Debug)]
pub enum BuildEnv {
    Development,
    Production,
}

impl fmt::Display for BuildEnv {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{}", format!("{:?}", self).to_lowercase())
    }
}

#[derive(Debug)]
pub enum BuildArch {
    X32,
    X64,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    lazy_static::initialize(&CTRL_C_RECEIVED);

    ctrlc::set_handler(move || {
        if CTRL_C_RECEIVED.load(Ordering::SeqCst) {
            exit(1);
        }

        CTRL_C_RECEIVED.store(true, Ordering::SeqCst);

        if let Err(e) = stop_receiver() {
            println!(
                "{} - {} - {}",
                "<esm_bt>".blue().bold(),
                "error".red().bold(),
                e
            );
            exit(1);
        }

        exit(0);
    })
    .expect("Error setting Ctrl-C handler");

    let mut builder = match Builder::new(Args::parse()) {
        Ok(b) => b,
        Err(e) => {
            println!(
                "{} - {} - {}",
                "<esm_bt>".blue().bold(),
                "error".red().bold(),
                e
            );
            exit(1)
        }
    };

    match builder.run() {
        Ok(_) => {}
        Err(e) => println!(
            "{} - {} - {}",
            "<esm_bt>".blue().bold(),
            "error".red().bold(),
            e
        ),
    };

    match builder.finish() {
        Ok(_) => {}
        Err(e) => println!(
            "{} - {} - {}",
            "<esm_bt>".blue().bold(),
            "error".red().bold(),
            e
        ),
    };

    Ok(())
}
