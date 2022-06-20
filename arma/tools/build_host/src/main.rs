// Most of this code was from the example, thank you!
// https://github.com/lemunozm/message-io/tree/master/examples/file-transfer

mod builder;
mod server;
mod transfer;

use std::{fmt, process::exit};

pub use build_common::*;
use builder::Builder;
use clap::{ArgEnum, Parser, Subcommand};
use colored::Colorize;

/// Builds ESM's Arma 3 server mod
#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    #[clap(subcommand)]
    command: Commands,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    Run {
        /// Build the extension as 32 bit instead of 64 bit
        #[clap(short, long)]
        build_x32: bool,

        /// Set the target build platform for the extension
        #[clap(short, long, arg_enum, default_value_t = BuildOS::Windows)]
        target: BuildOS,

        /// Sets the logging level for the extension and the mod
        #[clap(short, long, arg_enum, default_value_t = LogLevel::Debug)]
        log_level: LogLevel,

        /// Sets the logging level for the extension and the mod
        #[clap(short, long, arg_enum, default_value_t = BuildEnv::Development)]
        env: BuildEnv,

        /// The URI of the server hosting esm_bot
        #[clap(short, long,default_value_t = String::from("esm.mshome.net:3003"))]
        bot_host: String,
    },
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
pub enum BuildOS {
    Linux,
    Windows,
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
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

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
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

fn main() {
    let args = Args::parse();
    let mut builder = match Builder::new(args.command) {
        Ok(b) => b,
        Err(e) => {
            println!("{} - {}", "ERROR".red().bold(), e);
            exit(1)
        }
    };

    match builder.start() {
        Ok(_) => {}
        Err(e) => println!("{} - {}", "ERROR".red().bold(), e),
    };

    builder.teardown();
}
