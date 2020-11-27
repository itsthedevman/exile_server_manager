mod models;
mod util;
mod websocket_client;

#[macro_use]
extern crate arma_rs;

// Various Packages
use arma_rs::{rv, rv_callback};
use crossbeam_channel::{unbounded, Receiver, Sender};
use lazy_static::lazy_static;
use std::{env, fs, path::PathBuf, sync::Mutex, collections::HashMap};
use yaml_rust::{Yaml, YamlLoader};
use once_cell::sync::Lazy;

// Logging
use log::*;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config, Root};
use log4rs::encode::pattern::PatternEncoder;

// ESM Packages
pub use models::bot_command::BotCommand;
use websocket_client::WebsocketClient;

static METADATA: Lazy<Mutex<HashMap<&str, String>>> = Lazy::new(|| {
    Mutex::new(HashMap::new())
});

lazy_static! {
    static ref A3_SERVER: ArmaServer = ArmaServer::new();
}

pub struct ArmaServer {
    ext_path: PathBuf,
    wsc_queue: Sender<String>,
    config: Vec<Yaml>,
    ready: bool,
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        // Start the logger
        initialize_logger();

        let ext_path = match std::env::current_dir() {
            Ok(path) => path,
            Err(e) => panic!(format!("Failed to find current executable path: {}", e)),
        };

        let bot_config = initialize_config();

        // Any commands to be sent to the bot will use this channel set. These are Multiple Sender, Multiple Receiver channels
        let (sender, receiver) = unbounded();

        // The one, the only.
        let arma_server = ArmaServer {
            ext_path: ext_path,
            wsc_queue: sender,
            config: bot_config,
            ready: false,
        };

        // Connect to the bot
        arma_server.connect_to_bot(receiver);

        arma_server
    }

    fn connect_to_bot(&self, receiver: Receiver<String>) {
        let ws_url = self.config[0]["ws_url"].as_str().unwrap().to_string();

        WebsocketClient::connect_to_bot(ws_url, self.esm_key_path(), receiver);
    }

    fn esm_key_path(&self) -> String {
        let mut key_path = self.ext_path.clone();
        key_path.push("@ESM");
        key_path.push("esm.key");

        match key_path.into_os_string().into_string() {
            Ok(val) => val,
            Err(os_string) => {
                error!("Failed to build path for esm.key. Attempting lossy string conversion");
                os_string.to_string_lossy().to_string()
            }
        }
    }

    pub fn log(&self, message: String) {
        rv_callback!("esm", "ESM_fnc_log", "Extension", message);
    }

    pub fn send_to_bot(&self, package: BotCommand) {
        let channel = self.wsc_queue.clone();

        let package = match package.into_json() {
            Ok(val) => val,
            Err(err) => return error!("Failed to convert message into JSON: {}", err),
        };

        match channel.send(package) {
            Ok(_) => (),
            Err(err) => error!("Failed to send message to bot: {}", err),
        }
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
        Err(_) => String::from(
            "
                ws_url: ws://ws.esmbot.com
            ",
        ),
    };

    YamlLoader::load_from_str(&contents).unwrap()
}

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessible from callExtension
///////////////////////////////////////////////////////////////////////
#[rv(thread = true)]
fn pre_init(package: String) {
    if A3_SERVER.ready {
        return A3_SERVER.log(String::from(
            "ESM has already been marked as ready. Is the server boot looping?",
        ));
    }

    METADATA.lock().unwrap().insert("server_initalization", package.clone());

    debug!("Sending pre_init request to bot with package: {}", package);

    // Send the bot the package
    let package = BotCommand::new("server_initialization", package);
    A3_SERVER.send_to_bot(package);
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
