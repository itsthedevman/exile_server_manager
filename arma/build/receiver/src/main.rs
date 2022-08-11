mod client;
mod command;
mod database;
mod log_reader;
mod transfer;

use std::{path::{Path, PathBuf}, time::Duration};

use clap::Parser;
use client::Client;
pub use common::*;
pub use database::*;
use lazy_static::lazy_static;

lazy_static! {
    pub static ref ROOT_PATH: PathBuf = {
        if cfg!(windows) {
            Path::new("C:").to_path_buf()
        } else {
            Path::new("/").to_path_buf()
        }
    };
}

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    /// The build host's IP and port
    #[clap(short, long)]
    host: String,

    /// The database connection string. This is the same database the Exile server connects to.
    /// For example: mysql://user:password@host:port/database_name
    #[clap(short, long)]
    database_uri: String,

    /// The local path to where the mod is built before being copied over to the server
    #[clap(short, long,default_value_t = if cfg!(windows) { String::from("C:\\temp\\esm") } else { String::from("/tmp/esm") })]
    build_path: String,

    /// The path to the root directory that contains arma3server[_x64][.exe]
    #[clap(short, long)]
    a3_server_path: String,

    /// The server launch parameters for arma3server[_x64][.exe]
    #[clap(short, long)]
    a3_server_args: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let mut client = Client::new(args)?;

    loop {
        client.connect();
        std::thread::sleep(Duration::from_secs(1));
    }

    Ok(())
}
