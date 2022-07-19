mod arma;
mod client;
mod command;
mod database;
mod transfer;

use clap::Parser;
use client::Client;
pub use common::*;
pub use database::*;

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

    /// The path to the root directory that contains arma3server[_x64][.exe]
    #[clap(short, long)]
    a3_server_path: String,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let mut client = Client::new(args)?;
    client.connect();

    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
