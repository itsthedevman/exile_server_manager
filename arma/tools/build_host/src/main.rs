// Most of this code was from the example, thank you!
// https://github.com/lemunozm/message-io/tree/master/examples/file-transfer

mod builder;
mod server;

use builder::Builder;
use clap::{Parser, ArgEnum, Subcommand};

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
    }
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
    Trace
}

#[derive(Copy, Clone, PartialEq, Eq, PartialOrd, Ord, ArgEnum, Debug)]
pub enum BuildEnv {
    Development,
    Production
}

#[derive(Debug)]
pub enum BuildArch {
    X32,
    X64,
}

fn main() {
    let args = Args::parse();

    let mut builder = match args.command {
        Commands::Run { build_x32, target, log_level, env } => {
            Builder::new(build_x32, target, log_level, env)
        }
    };

    builder.start();
}
