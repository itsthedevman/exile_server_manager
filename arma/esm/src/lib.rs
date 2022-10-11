mod arma;
mod bot;
mod config;
mod connection_manager;
mod database;
mod error;
mod macros;
mod router;
mod token;

// Various Packages
use arma_rs::{arma, Context, Extension};
use chrono::prelude::*;
use lazy_static::lazy_static;
use std::sync::atomic::{AtomicBool, Ordering};
pub use std::sync::Arc;
use std::{env, fs};
use tokio::runtime::Runtime;
pub use tokio::sync::Mutex;

// Logging
pub use log::{debug, error, info, trace, warn};
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;

use config::Config;
use config::Env;

pub use bot::TOKEN_MANAGER;
pub use error::*;
pub use esm_message::*;
pub use macros::*;

use crate::router::{Router, RoutingCommand};

pub type ESMResult = Result<(), ESMError>;
pub type MessageResult = Result<Option<Message>, ESMError>;

lazy_static! {
    /// Represents @esm/config.yml
    pub static ref CONFIG: Config = Config::new();

    /// Is the extension ready to receive messages?
    pub static ref READY: AtomicBool = AtomicBool::new(false);

    /// The runtime for the asynchronous code
    pub static ref TOKIO_RUNTIME: Arc<Runtime> = Arc::new(tokio::runtime::Builder::new_multi_thread().enable_all().build().unwrap());

    /// Handles sending messages to the Bot and the A3 server
    pub static ref ROUTER: Arc<Router> = Arc::new(Router::new());
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
        "\n----------------------------------\nWelcome to Exile Server Manager v{} Build {}\nLoaded config {}\n----------------------------------",
        env!("CARGO_PKG_VERSION"),
        std::include_str!("../.build-sha"),
        CONFIG.to_string()
    );
}

///////////////////////////////////////////////////////////////////////
// START Arma accessible functions
///////////////////////////////////////////////////////////////////////
#[arma]
pub fn init() -> Extension {
    // Start the logger
    initialize_logger();

    debug!("[extension#init] - Initializing");

    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);

    Extension::build()
        .command("log", log)
        .command("log_output", log_output)
        .command("log_level", log_level)
        .command("utc_timestamp", utc_timestamp)
        .command("pre_init", pre_init)
        .command("send_message", send_message)
        .command("send_to_channel", send_to_channel)
        .finish()
}

fn pre_init(
    callback: Context,
    server_name: String,
    price_per_object: NumberString,
    territory_lifetime: NumberString,
    territory_data: String,
    vg_enabled: bool,
    vg_max_sizes: String,
) {
    let timer = std::time::Instant::now();
    debug!(
        r#"[extension#pre_init]
            server_name: {:?}
            price_per_object: {:?}
            territory_lifetime: {:?}
            territory_data: {:?}
            vg_enabled: {:?}
            vg_max_sizes: {:?}
        "#,
        server_name, price_per_object, territory_lifetime, territory_data, vg_enabled, vg_max_sizes
    );

    std::thread::spawn(move || {
        TOKIO_RUNTIME.block_on(async {
            // Only allow this method to be called properly once
            if READY.load(Ordering::SeqCst) {
                warn!("[extension#pre_init] ⚠ This endpoint can only be called once. Perhaps your server is boot looping?");
                return;
            }

            info!("[extension#pre_init] Exile Server Manager (extension) is booting");
            info!("[extension#pre_init]    Validating config file");

            if let Err(e) = CONFIG.validate() {
                error!("[extension#pre_init] ❌ Boot failed - Invalid config file");
                warn!("[config#validate] ⚠ {}", e);
                error!("[extension#pre_init] ❌ Boot failed - You must fix the above warning before Exile Server Manager can boot");
                return;
            }

            info!("[extension#pre_init]    Validating initialization package");

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

            if let Err(errors) = init.validate() {
                debug!("{:#?}", init);
                error!("[extension#pre_init] ❌ Boot failed - Invalid initialization data provided");

                for error in errors {
                    warn!("[init#validate] ⚠ {error}");
                }

                error!("[extension#pre_init] ❌ Boot failed - You must fix the above warnings before Exile Server Manager can boot");
                return;
            }

            info!("[extension#pre_init]    Greeting our new friend - Hello {}!", init.server_name);
            if let Err(e) = crate::ROUTER.route_internal("arma", RoutingCommand::ArmaInitialize { context: callback }) {
                error!("[extension#pre_init] ❌ Boot failed - Failed to initialize Arma");
                warn!("[extension#pre_init] ⚠ {e}");
                error!("[extension#pre_init] ❌ Boot failed");
            };

            info!("[extension#pre_init]    Remembering to greet ourselves - Hello ESM!");
            if let Err(e) = crate::ROUTER.route_internal("bot", RoutingCommand::ClientInitialize { init }) {
                error!("[extension#pre_init] ❌ Boot failed - Failed to initialize Bot");
                warn!("[extension#pre_init] ⚠ {e}");
                error!("[extension#pre_init] ❌ Boot failed");
            };

            info!("[extension#pre_init] ✅ Boot completed in {:.2?}", timer.elapsed());
        });
    });
}

fn send_message(id: String, message_type: String, data: String, metadata: String, errors: String) {
    let timer = std::time::Instant::now();
    debug!(
        "[extension#send_message]\nid: {:?}\ntype: {:?}\ndata: {:?}\nmetadata: {:?}\nerrors: {:?}",
        id, message_type, data, metadata, errors
    );

    std::thread::spawn(move || {
        TOKIO_RUNTIME.block_on(async {
            let message = match Message::from_arma(id, message_type, data, metadata, errors) {
                Ok(m) => m,
                Err(e) => return error!("[extension#send_message] ❌ {}", e),
            };

            if let Err(e) = crate::ROUTER.route_to_bot(message) {
                error!("[extension#send_message] ❌ {}", e);
            };

            info!("[extension#send_message] ⏲ Took {:.2?}", timer.elapsed());
        });
    });
}

fn send_to_channel(id: String, content: String) {
    let timer = std::time::Instant::now();
    debug!(
        "[extension#send_to_channel] id: {:?} - content: {:?}",
        id, content
    );

    std::thread::spawn(move || {
        TOKIO_RUNTIME.block_on(async {
            let mut message = Message::new(Type::Event);
            message.data = Data::SendToChannel(data::SendToChannel { id, content });

            if let Err(e) = crate::ROUTER.route_to_bot(message) {
                error!("[extension#send_to_channel] ❌ {}", e);
            };

            info!("[extension#send_to_channel] ⏲ Took {:.2?}", timer.elapsed());
        });
    });
}

fn utc_timestamp() -> String {
    let timestamp = Utc::now().to_rfc3339();
    debug!("[extension#utc_timestamp] - {timestamp}");

    timestamp
}

fn log_level() -> String {
    let log_level = CONFIG.log_level.to_lowercase();
    debug!("[extension#log_level] - {log_level}");

    log_level
}

fn log_output() -> String {
    let log_output = CONFIG.log_output.to_lowercase();
    debug!("[extension#log_output] - {log_output}");

    log_output
}

fn log(log_level: String, caller: String, content: String) {
    let timer = std::time::Instant::now();
    trace!(
        "[extension#log] log_level: {:?} - caller: {:?} - content size: {:?} bytes",
        log_level,
        caller,
        content.len()
    );

    TOKIO_RUNTIME.block_on(async {
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

        trace!("[extension#log] ⏲ Took {:.2?}", timer.elapsed());
    });
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
