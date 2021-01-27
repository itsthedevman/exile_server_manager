mod arma_server;
mod bot;
mod bot_command;
mod command;
mod websocket_client;

// ESM Packages
use arma_server::ArmaServer;
use bot::Bot;
use command::Command;

#[macro_use]
extern crate arma_rs;

// Various Packages
use arma_rs::{rv, rv_callback};
use lazy_static::lazy_static;
use std::{env, fs, sync::RwLock, collections::HashMap};
use yaml_rust::{Yaml, YamlLoader};
use serde_json::{json, Value};
use chrono::prelude::*;

// Logging
use log::*;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config, Root};
use log4rs::encode::pattern::PatternEncoder;

lazy_static! {
    // Any metadata I need to have stored across threads
    pub static ref METADATA: RwLock<HashMap<&'static str, String>> = RwLock::new(HashMap::new());

    // Config data
    pub static ref CONFIG: Vec<Yaml> = {
        let contents = match fs::read_to_string("@ESM/config.yml") {
            Ok(file) => file,
            Err(_) => String::from(
                "
                    ws_url: ws://ws.esmbot.com
                ",
            ),
        };

        YamlLoader::load_from_str(&contents).unwrap()
    };

    // Contains a connection to the Discord bot and various methods involving it
    pub static ref BOT: Bot = Bot::new();

    // Data and methods regarding the Arma server
    pub static ref A3_SERVER: ArmaServer = ArmaServer::new();
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

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessible from callExtension
///////////////////////////////////////////////////////////////////////
#[rv(thread = true)]
fn pre_init(server_name: String, price_per_object: f32, territory_lifetime: f32, territory_data: String) {
    if BOT.ready {
        return error!("[pre_init] ESM has already been initialized. Is the server boot looping?");
    }

    let territory_data: Vec<Value> = match serde_json::from_str(&territory_data) {
        Ok(data) => data,
        Err(e) => return error!("[pre_init] Unable to parse territory data: {}", e)
    };

    let package = json!({
        "server_name": server_name,
        "price_per_object": price_per_object,
        "territory_lifetime": territory_lifetime,
        "territory_data": territory_data,
        "server_start_time": Utc::now().to_rfc3339()
    });

    let package = package.to_string();
    METADATA.write().unwrap().insert("server_initialization", package.clone());
    info!("[pre_init] Done");
}

#[rv]
fn is_arma3(version: u8) -> bool {
    version == 3
}

#[rv_handler]
fn init() {
    // Start the logger
    initialize_logger();
}
