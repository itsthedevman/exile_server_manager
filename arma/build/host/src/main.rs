// Most of this code was from the example, thank you!
// https://github.com/lemunozm/message-io/tree/master/examples/file-transfer

mod builder;
mod compile;
mod data;
mod database;
mod directory;
mod file;
mod file_watcher;
mod server;

use std::{
    fmt::{self, Display},
    process::exit,
    sync::atomic::{AtomicBool, Ordering},
};

use builder::Builder;
use clap::{Parser, ValueEnum};
use colored::Colorize;
pub use common::*;
pub use directory::*;
pub use file::*;
use lazy_static::lazy_static;
use parking_lot::RwLock;
pub use std::process::Command as SystemCommand;

use crate::server::Server;

lazy_static! {
    pub static ref SERVER: RwLock<Server> = RwLock::new(Server::new());
    pub static ref CTRL_C_RECEIVED: AtomicBool = AtomicBool::new(false);
}

/// Builds ESM's Arma 3 server mod
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    /// Build the extension as 32 bit instead of 64 bit
    #[arg(short, long)]
    build_x32: bool,

    /// Set the target build platform for the extension
    #[arg(short, long, value_enum, default_value_t = BuildOS::Windows)]
    target: BuildOS,

    /// Sets the logging level for the extension and the mod
    #[arg(short, long, value_enum, default_value_t = LogLevel::Debug)]
    log_level: LogLevel,

    /// Sets the logging level for the extension and the mod
    #[arg(short, long, value_enum, default_value_t = BuildEnv::Development)]
    env: BuildEnv,

    /// The URI of the server hosting esm_bot
    #[arg(short, long, default_value_t = String::from("192.168.50.242:3003"))]
    bot_host: String,

    /// Forces a rebuild of everything
    #[arg(short, long)]
    force: bool,

    /// Sets the release flag
    #[arg(short, long)]
    release: bool,

    /// Space or comma separated list that controls which pieces are built
    #[arg(short, long, value_parser = ["mod", "extension"])]
    only: Option<String>,
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
    Test,
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
    lazy_static::initialize(&SERVER);
    lazy_static::initialize(&CTRL_C_RECEIVED);

    ctrlc::set_handler(move || {
        if CTRL_C_RECEIVED.load(Ordering::SeqCst) {
            exit(1);
        }

        CTRL_C_RECEIVED.store(true, Ordering::SeqCst);

        let result = write_lock(&SERVER, |mut server| {
            server.stop();
            Ok(true)
        });

        if result.is_err() {
            println!(
                "{} - {} - {}",
                "<esm_bt>".blue().bold(),
                "error".red().bold(),
                result.err().unwrap()
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

    match builder.start() {
        Ok(_) => {}
        Err(e) => println!(
            "{} - {} - {}",
            "<esm_bt>".blue().bold(),
            "error".red().bold(),
            e
        ),
    };

    write_lock(&SERVER, |mut server| {
        server.stop();
        Ok(true)
    })?;

    Ok(())
}
