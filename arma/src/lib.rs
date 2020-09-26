mod websocket_client;

#[macro_use]
extern crate arma_rs;

// Various Packages
use arma_rs::{rv, rv_callback};
use crossbeam_channel::{bounded, Sender};
use lazy_static::lazy_static;
use std::{env, fs, sync::Mutex};
use yaml_rust::{YamlLoader, Yaml};

// Logging
use log::*;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config, Root};
use log4rs::encode::pattern::PatternEncoder;

// ESM Packages
use websocket_client::WebsocketClient;

lazy_static! {
    static ref A3_SERVER: ArmaServer = ArmaServer::new();
}

pub struct ArmaServer {
    ext_path: String,
    sender: Mutex<Sender<String>>,
    config: Vec<Yaml>
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
            config: initialize_config()
        };

        // Connect to the bot
        arma_server.connect_to_bot();

        arma_server
    }

    fn connect_to_bot(&mut self) {
        let sender = WebsocketClient::connect_to_bot(&self.ext_path, &self.config);
        self.sender = Mutex::new(sender);
    }

    pub fn log(&self, message: String) {
        debug!("[ArmaServer::log] {}", message);
        rv_callback!("esm", "ESM_fnc_log", "Extension", message);
    }
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
        .build("@ESM/log/esm.log")
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

    info!(
        "\n----------------------------------\nExile Server Manager v{}\n----------------------------------",
        env!("CARGO_PKG_VERSION")
    );
}

fn initialize_config() -> Vec<Yaml> {
    let contents = match fs::read_to_string("@ESM/config.yml") {
        Ok(file) => file,
        Err(_) => {
            "
                ws_url: ws://ws.esmbot.com
            ".to_string()
        }
    };

    YamlLoader::load_from_str(&contents).unwrap()
}

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessable from callExtension
///////////////////////////////////////////////////////////////////////
#[rv(thread=true)]
fn pre_init(package: String) {
    initialize_logger();
    A3_SERVER.log(format!("Sending pre_init request to bot with package: {}", package));
}

// For some reason, rv_handler requires `#is_arma3` and `#initialize` to be defined...
#[rv]
fn is_arma3(version: u8) -> bool {
    version == 3
}

#[rv]
fn initialize() {}

#[rv_handler]
fn main() {}
