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
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();
    let mut client = Client::new(args.host, args.database_uri)?;
    client.connect();

    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
