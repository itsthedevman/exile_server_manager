mod client;

use client::Client;
use clap::{Parser};


#[derive(Parser, Debug)]
#[clap(author, version, about, long_about = None)]
pub struct Args {
    /// The build host's IP and port
    #[clap(short, long)]
    host: String,
}

fn main() {
    let args = Args::parse();
    let mut client = Client::new(args.host);
    client.connect();

    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    };
}
