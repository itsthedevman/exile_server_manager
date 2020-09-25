mod websocket_client;

use arma_rs::{rv, rv_handler, rv_callback};
use log::*;
use websocket_client::WebsocketClient;
use lazy_static::lazy_static;
use std::sync::Mutex;
use crossbeam_channel::{Sender, bounded};

lazy_static! {
    static ref A3_SERVER: ArmaServer = ArmaServer::new();
}

// Required
// This is called when the Arma server requests the DLL version
#[rv_handler]
pub fn init() {
    env_logger::init();

    A3_SERVER.log("Extension Initialization");
}

// Required
#[rv]
#[allow(dead_code)]
fn is_arma3(version: u8) -> bool {
    version == 3
}

pub struct ArmaServer {
    ext_path: String,
    sender: Mutex<Sender<String>>
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        let mut ext_path = match std::env::current_exe() {
            Ok(path) => path.to_string_lossy().to_string(),
            Err(e) => panic!(format!("Failed to find current executable path: {}", e))
        };

        if cfg!(debug_assertions) {
            ext_path = ext_path.replace("/extension/target/debug/esm", "/sqf/@ESM");
        }

        // Create a temp channel that will be replaced after connecting to the bot.
        let (temp_sender, _receiver) = bounded(0);

        let mut arma_server = ArmaServer {
            ext_path: ext_path,
            sender: Mutex::new(temp_sender)
        };

        // Connect to the bot
        arma_server.connect_to_bot();

        arma_server
    }

    fn connect_to_bot(&mut self) {
        let sender = WebsocketClient::connect_to_bot(&self.ext_path);
        self.sender = Mutex::new(sender);
    }

    pub fn log(&self, message: &'static str) {
        debug!("[ArmaServer::log] {}", message);
        rv_callback!("esm", "ESM_fnc_log", message);
    }
}
