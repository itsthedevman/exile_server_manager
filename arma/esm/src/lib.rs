mod arma;
mod bot;
mod client;
mod config;
mod database;
mod error;
mod token;

// Various Packages
use arma_rs::{arma, Context, Extension};
use chrono::prelude::*;
use esm_message::*;
use lazy_static::lazy_static;
pub use parking_lot::RwLock;
use std::sync::atomic::{AtomicBool, AtomicUsize, Ordering};
use std::time::Duration;
use std::{env, fs, thread};

// Logging
pub use log::{debug, error, info, trace, warn};
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;

use arma::Arma;
use bot::Bot;
use config::Config;

use crate::config::Env;

lazy_static! {
    /// Represents @esm/config.yml
    pub static ref CONFIG: Config = {
        let contents = match fs::read_to_string("@esm/config.yml") {
            Ok(file) => file,
            Err(_) => String::from(""),
        };

        let config: Config = match serde_yaml::from_str(&contents) {
            Ok(config) => config,
            Err(_) => Config::new()
        };

        config
    };

    /// Is the extension ready to receive messages?
    pub static ref READY: AtomicBool = AtomicBool::new(false);

    /// Represents the connection to the A3 server
    pub static ref ARMA: RwLock<Arma> = RwLock::new(Arma::new());

    /// Represents the connection to the bot
    pub static ref BOT: RwLock<Bot> = RwLock::new(Bot::new());
}

fn initialize_logger() {
    let log_pattern = "[{d(%Y-%m-%d %H:%M:%S)} {h({l})}] {m}{n}";
    let stdout = ConsoleAppender::builder()
        .encoder(Box::new(PatternEncoder::new(log_pattern)))
        .build();

    let logfile = FileAppender::builder()
        .encoder(Box::new(PatternEncoder::new(log_pattern)))
        .build(crate::CONFIG.logging_path.clone())
        .unwrap();

    let log_level = match crate::CONFIG.log_level.as_ref() {
        "trace" => log::LevelFilter::Trace,
        "debug" => log::LevelFilter::Debug,
        "warn" => log::LevelFilter::Warn,
        "error" => log::LevelFilter::Error,
        _ => log::LevelFilter::Info,
    };

    let config = LogConfig::builder()
        .appender(Appender::builder().build("stdout", Box::new(stdout)))
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(
            Root::builder()
                .appender("logfile")
                .appender("stdout")
                .build(log_level),
        )
        .unwrap();

    match log4rs::init_config(config) {
        Ok(_) => (),
        Err(e) => println!("[ERROR] Failed to initialize logger - {e}"),
    };

    info!(
        "\n----------------------------------\nWelcome to Exile Server Manager v{} Build {}\nLoaded config {:#?}\n----------------------------------",
        env!("CARGO_PKG_VERSION"),
        std::include_str!("../.build-sha"),
        crate::CONFIG.to_hashmap()
    );
}

fn connection_manager() {
    let reconnection_counter = AtomicUsize::new(0);
    thread::spawn(move || loop {
        let mut bot = BOT.write();
        let connected = bot.client.connected.clone();
        if let Err(e) = bot.connect() {
            error!("[#pre_init] Pre init failed! {}. ", e);
            return;
        };

        while connected.load(Ordering::SeqCst) {
            reconnection_counter.store(0, Ordering::SeqCst);
            std::thread::sleep(Duration::from_secs(1));
        }

        // Get the current reconnection count and calculate the wait time
        let current_count = reconnection_counter.load(Ordering::SeqCst);
        let time_to_wait = match crate::CONFIG.env {
            Env::Test => 1,
            Env::Development => 3,
            _ => current_count * 15,
        };

        let time_to_wait = Duration::from_secs(time_to_wait as u64);
        warn!(
            "[connection_manager] Lost connection to esm_bot - Attempting reconnect in {:?}",
            time_to_wait
        );

        // Sleep a max of 5 minutes
        if current_count <= 20 {
            // Increase the reconnect counter by 1
            reconnection_counter.fetch_add(1, Ordering::SeqCst);
        }

        std::thread::sleep(time_to_wait);
    });
}

///////////////////////////////////////////////////////////////////////
// START Arma accessible functions
///////////////////////////////////////////////////////////////////////
#[arma]
pub fn init() -> Extension {
    trace!("[#init] - Starting");

    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);

    // Start the logger
    initialize_logger();

    Extension::build()
        .command("log", log)
        .command("utc_timestamp", utc_timestamp)
        .command("log_level", log_level)
        .command("pre_init", pre_init)
        .command("send_message", send_message)
        .command("send_to_channel", send_to_channel)
        .finish()
}

pub fn pre_init(
    callback: Context,
    server_name: String,
    price_per_object: NumberString,
    territory_lifetime: NumberString,
    territory_data: String,
    vg_enabled: bool,
    vg_max_sizes: String,
) -> bool {
    trace!(
        r#"[#pre_init]
            server_name: {:?}
            price_per_object: {:?}
            territory_lifetime: {:?}
            territory_data: {:?}
            vg_enabled: {:?}
            vg_max_sizes: {:?}
        "#,
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        vg_enabled,
        vg_max_sizes
    );

    // Only allow this method to be called properly once
    if READY.load(Ordering::SeqCst) {
        warn!("[#pre_init] This endpoint can only be called once. Perhaps your server is boot looping?");
        return false;
    }

    info!("[#pre_init] Exile Server Manager (extension) is booting");

    // Using the data from the a3 server, create a data packet to be used whenever the server connects to the bot.
    let init = Init {
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        vg_enabled,
        vg_max_sizes,
        server_start_time: Utc::now(),
        extension_version: format!(
            "{}+{}",
            env!("CARGO_PKG_VERSION"),
            std::include_str!("../.build-sha")
        ),
    };

    debug!("[#pre_init] Initialization Data - {:?}", init);

    if !init.valid() {
        error!(
            "[#pre_init] Cannot boot - Received invalid initialization data. {:?}",
            init
        );
        return false;
    }

    ARMA.write().initialize(init, callback);

    info!("[#pre_init]    Attempting to shake hands with esm_bot. Remember: good posture, eye contact and a firm grip");

    connection_manager();

    info!("[#pre_init] Boot completed");
    true
}

pub fn send_message(
    id: String,
    message_type: String,
    data: String,
    metadata: String,
    errors: String,
) {
    debug!(
        "[#send_message]\nid: {:?}\ntype: {:?}\ndata: {:?}\nmetadata: {:?}\nerrors: {:?}",
        id, message_type, data, metadata, errors
    );

    let message = match Message::from_arma(id, message_type, data, metadata, errors) {
        Ok(m) => m,
        Err(e) => return error!("[#send_message] {}", e),
    };

    if let Err(e) = crate::BOT.write().send(message) {
        error!("[#send_message] {}", e);
    };
}

pub fn send_to_channel(id: String, content: String) {
    debug!("[#send_to_channel]\nid: {:?}\ncontent: {:?}", id, content);

    let mut message = Message::new(Type::Event);
    message.data = Data::SendToChannel(data::SendToChannel { id, content });

    if let Err(e) = crate::BOT.write().send(message) {
        error!("[#send_to_channel] {}", e);
    };
}

pub fn utc_timestamp() -> String {
    let timestamp = Utc::now().to_rfc3339();
    debug!("[#utc_timestamp] - {timestamp}");

    timestamp
}

pub fn log_level() -> String {
    let log_level = CONFIG.log_level.to_lowercase();
    debug!("[#log_level] - {log_level}");

    log_level
}

pub fn log(log_level: String, caller: String, content: String) {
    let message = format!("{caller} | {content}");

    match log_level.to_ascii_lowercase().as_str() {
        "trace" => trace!("{message}"),
        "debug" => debug!("{message}"),
        "info" => info!("{message}"),
        "warn" => warn!("{message}"),
        "error" => error!("{message}"),
        t => error!(
            "[#log] Invalid log level provided. Received {}, expected debug, info, warn, error",
            t
        ),
    }
}

///////////////////////////////////////////////////////////////////////
// END Arma accessible functions
///////////////////////////////////////////////////////////////////////

#[cfg(test)]
mod tests {
    use super::init;
    use regex::Regex;

    #[test]
    fn it_returns_current_timestamp() {
        let extension = init().testing();
        let (result, _) = unsafe { extension.call("utc_timestamp", None) };

        // "2021-01-01T00:00:00.000000000+00:00"
        let re =
            Regex::new(r#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}\+\d{2}:\d{2}$"#).unwrap();

        assert!(re.is_match(&result));
    }

    #[test]
    fn it_returns_log_level() {
        let extension = init().testing();
        let (result, _) = unsafe { extension.call("log_level", None) };
        assert_eq!(result, "info");
    }
}
