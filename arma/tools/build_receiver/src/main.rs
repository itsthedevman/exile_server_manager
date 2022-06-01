mod client;

use client::Client;
use lazy_static::lazy_static;

lazy_static! {
    pub static ref CLIENT: Client = Client::new();
}

fn main() {
    lazy_static::initialize(&CLIENT);
}
