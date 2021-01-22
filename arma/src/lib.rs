mod websocket_client;
mod bot_command;

#[macro_use]
extern crate arma_rs;

// Various Packages
use arma_rs::{rv, rv_callback};
use crossbeam_channel::{unbounded, Receiver, Sender};
use lazy_static::lazy_static;
use std::{env, fs, sync::RwLock, collections::HashMap};
use yaml_rust::{Yaml, YamlLoader};
use serde_json::{json, Value};

// Logging
use log::*;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config, Root};
use log4rs::encode::pattern::PatternEncoder;

// ESM Packages
pub use bot_command::BotCommand;
use websocket_client::WebsocketClient;

lazy_static! {
    // Any metadata I need to have stored across threads
    pub static ref METADATA: RwLock<HashMap<&'static str, String>> = RwLock::new(HashMap::new());

    // Config data
    pub static ref CONFIG: Vec<Yaml> = initialize_config();

    // The connection to the bot
    pub static ref BOT: Bot = Bot::new();

    // // The path to the arma3server executable
    // pub static ref EXE_PATH: PathBuf = {
    //     let path = match std::env::current_dir() {
    //         Ok(path) => path,
    //         Err(e) => panic!(format!("Failed to find current executable path: {}", e)),
    //     };

    //     path
    // };
}

pub struct Bot {
    send_queue: Sender<String>,
    ready: bool,
}

impl Bot {
    pub fn new() -> Bot {
        // Any commands to be sent to the bot will use this channel set. These are Multiple Sender, Multiple Receiver channels
        let (sender, receiver) = unbounded();

        // The one, the only.
        let esm_bot = Bot { send_queue: sender, ready: false, };

        // Connect to the bot
        esm_bot.connect(receiver);

        esm_bot
    }

    fn connect(&self, receiver: Receiver<String>) {
        let ws_url = CONFIG[0]["ws_url"].as_str().unwrap().to_string();

        WebsocketClient::connect(ws_url, receiver);
    }

    pub fn send(&self, package: String) {
        let channel = self.send_queue.clone();

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
fn pre_init(server_name: String, price_per_object: f32, territory_lifetime: f32, territory_data: String) {
    if BOT.ready {
        return error!("ESM has already been initialized. Is the server boot looping?");
    }

    let territory_data: Vec<Value> = match serde_json::from_str(&territory_data) {
        Ok(data) => data,
        Err(e) => return error!("Unable to parse territory data: {}", e)
    };

    let package = json!({
        "server_name": server_name,
        "price_per_object": price_per_object,
        "territory_lifetime": territory_lifetime,
        "territory_data": territory_data
    });

    let package = package.to_string();

    METADATA.write().unwrap().insert("server_initialization", package.clone());
    debug!("[pre_init] Request to bot with package: {}", &package);

    BOT.send(package);
}

// For some reason, rv_handler requires `#is_arma3` and `#initialize` to be defined...
#[rv]
fn is_arma3(version: u8) -> bool {
    version == 3
}

#[rv_handler]
fn init() {
    // Start the logger
    initialize_logger();
}
