mod websocket_client;

use arma_rs::{rv, rv_handler, rv_callback};
use log::*;
use websocket_client::WebsocketClient;
use lazy_static::lazy_static;

lazy_static! {
    static ref A3_SERVER: ArmaServer = ArmaServer::new();
}

// Required
// This is called when the Arma server requests the DLL version
#[rv_handler]
pub fn init() {
    A3_SERVER.log("Extension Initialization");

    env_logger::init();

    debug!("{:?}", A3_SERVER.ext_path);

    A3_SERVER.connect_to_bot();
}

// Required
#[rv]
#[allow(dead_code)]
fn is_arma3(version: u8) -> bool {
    version == 3
}

pub struct ArmaServer {
    ext_path: String
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

        ArmaServer { ext_path: ext_path }
    }

    pub fn connect_to_bot(&self) {
        WebsocketClient::connect_to_bot(&self.ext_path);
    }

    pub fn log(&self, message: &'static str) {
        debug!("[ArmaServer::log] {}", message);
        rv_callback!("esm", "ESM_fnc_log", message);
    }
}
