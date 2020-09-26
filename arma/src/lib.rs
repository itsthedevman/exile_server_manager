mod websocket_client;

use arma_rs::{rv, rv_callback, rv_handler};
use crossbeam_channel::{bounded, Sender};
use lazy_static::lazy_static;
use std::{env, sync::Mutex};
use websocket_client::WebsocketClient;

use log::*;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config, Root};
use log4rs::encode::pattern::PatternEncoder;

lazy_static! {
    static ref A3_SERVER: ArmaServer = ArmaServer::new();
}

pub struct ArmaServer {
    ext_path: String,
    sender: Mutex<Sender<String>>,
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        let ext_path = match std::env::current_exe() {
            Ok(path) => path.to_string_lossy().to_string(),
            Err(e) => panic!(format!("Failed to find current executable path: {}", e)),
        };

        // Create a temp channel that will be replaced after connecting to the bot.
        let (temp_sender, _receiver) = bounded(0);

        let mut arma_server = ArmaServer {
            ext_path: ext_path,
            sender: Mutex::new(temp_sender),
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

// Required
// This is called when the Arma server requests the DLL version
#[rv_handler]
fn init() {
    initialize_logger();
}

#[rv]
#[allow(dead_code)]
fn initialize(json: String) -> String {
    A3_SERVER.log("Extension Initialization");
    debug!("{}", json);

    "[667]".to_string()
}

// Required
#[rv]
#[allow(dead_code)]
fn is_arma3(version: u8) -> bool {
    version == 3
}

fn initialize_logger() {
    let stdout = ConsoleAppender::builder()
        .encoder(Box::new(PatternEncoder::new(
            "{d(%Y-%m-%d %H:%M:%S)} {l} - {m}\n",
        )))
        .build();

    let logfile = FileAppender::builder()
        .encoder(Box::new(PatternEncoder::new(
            "{d(%Y-%m-%d %H:%M:%S)} {l} - {m}\n",
        )))
        .build("log/esm.log")
        .unwrap();

    let config = Config::builder()
        .appender(Appender::builder().build("stdout", Box::new(stdout)))
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(
            Root::builder()
                .appender("logfile")
                .appender("stdout")
                .build(LevelFilter::Debug),
        )
        .unwrap();

    log4rs::init_config(config).unwrap();
}
