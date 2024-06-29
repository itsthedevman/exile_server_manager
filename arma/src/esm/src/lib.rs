// Various Packages
use arma_rs::{arma, Context, Extension};
use chrono::prelude::*;
use lazy_static::lazy_static;
use num_format::{Locale, ToFormattedString};
pub use serde_json::{json, Value as JSONValue};
pub use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, Ordering};
pub use std::sync::Arc;
pub use std::sync::Mutex as SyncMutex;
use std::{env, fs};
use tokio::runtime::Runtime;
pub use tokio::sync::Mutex;

// Logging
pub use log::{debug, error, info, trace, warn};
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;

use config::Config;

mod arma;
mod bot;
mod config;
mod database;
mod encryption;
mod error;
mod macros;
mod message;
mod parser;
mod request;
mod router;
mod token;

pub use bot::TOKEN_MANAGER;
pub use error::*;
pub use message::*;
pub use request::*;
pub use router::ROUTER;

pub type ESMResult = Result<(), Error>;
pub type MessageResult = Result<Option<Message>, Error>;
pub type NumberString = String;

lazy_static! {
    /// Represents @esm/config.yml
    pub static ref CONFIG: Config = Config::new();

    /// Is the extension ready to receive messages?
    pub static ref READY: AtomicBool = AtomicBool::new(false);

    /// The runtime for the asynchronous code
    pub static ref TOKIO_RUNTIME: Arc<Runtime> = Arc::new(tokio::runtime::Builder::new_multi_thread().enable_all().build().unwrap());
}

fn initialize_logger() {
    let log_pattern = "[{d(%Y-%m-%d %H:%M:%S%.3f)(utc)}Z {h({l})} {M}:{L}] {m}{n}";

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
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(Root::builder().appender("logfile").build(log_level));

    match config {
        Ok(c) => match log4rs::init_config(c) {
            Ok(_) => (),
            Err(e) => println!("[ERROR] Failed to initialize logger - {e}"),
        },
        Err(e) => println!("[ERROR] Failed to build logger config - {e}"),
    };

    info!(
        "\n----------------------------------\nWelcome to Exile Server Manager v{}.{}\n---\n{}\n----------------------------------",
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

    debug!("[init] - Initializing");

    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);

    Extension::build()
        .command("log_level", log_level)
        .command("log_output", log_output)
        .command("log", log)
        .command("number_to_string", number_to_string)
        .command("pre_init", pre_init)
        .command("send_message", send_message)
        .command("send_to_channel", send_to_channel)
        .command("utc_timestamp", utc_timestamp)
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
    // Only allow this method to be called properly once
    if READY.load(Ordering::SeqCst) {
        error!("[pre_init] ⚠ This endpoint can only be called once. Perhaps your server is boot looping?");
        return;
    }

    let timer = std::time::Instant::now();
    debug!(
        r#"[pre_init]
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
        // Router must be initialized outside the async context
        lazy_static::initialize(&ROUTER);

        TOKIO_RUNTIME.block_on(async {
            info!("[pre_init] Exile Server Manager (extension) is initializing");
            info!("[pre_init]   Validating config file...");

            if let Err(e) = CONFIG.validate() {
                error!("[pre_init] ❌ Boot failed - Invalid config file");
                warn!("[validate] ⚠ {}", e);
                error!("[pre_init] ❌ Boot failed - You must fix the above warning before Exile Server Manager can boot");
                return;
            }

            info!("[pre_init]   Validating initialization package...");

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
                error!("[pre_init] ❌ Boot failed - Invalid initialization data provided");

                for error in errors {
                    warn!("[validate] ⚠ {error}");
                }

                error!("[pre_init] ❌ Boot failed - You must fix the above warnings before Exile Server Manager can boot");
                return;
            }

            info!("[pre_init]   Initializing...");

            if let Err(e) = ArmaRequest::initialize(callback) {
                error!("[pre_init] ❌ Boot failed - Failed to initialize connection to Arma");
                warn!("[pre_init] ⚠ {e}");
                error!("[pre_init] ❌ Boot failed");
            };

            if let Err(e) = BotRequest::initialize(init) {
                error!("[pre_init] ❌ Boot failed - Failed to initialize connection to the bot");
                warn!("[pre_init] ⚠ {e}");
                error!("[pre_init] ❌ Boot failed");
                return;
            };

            info!("[pre_init] ✅ Initialization completed in {:.2?}", timer.elapsed());
        });
    });
}

fn send_message(id: String, message_type: String, data: String, metadata: String, errors: String) {
    if !READY.load(Ordering::SeqCst) {
        error!(
            "[send_message] ⚠ This endpoint cannot be accessed before \"pre_init\" has completed"
        );
        return;
    }

    let timer = std::time::Instant::now();
    trace!(
        "[send_message]\nid: {:?}\ntype: {:?}\ndata: {:?}\nmetadata: {:?}\nerrors: {:?}",
        id,
        message_type,
        data,
        metadata,
        errors
    );

    std::thread::spawn(move || {
        TOKIO_RUNTIME.block_on(async {
            let message = match Message::from_arma(id, message_type, data, metadata, errors) {
                Ok(m) => m,
                Err(e) => return error!("[send_message] ❌ {}", e),
            };

            if let Err(e) = BotRequest::send(message) {
                error!("[send_message] ❌ {}", e);
            };

            debug!("[send_message] ⏲ Took {:.2?}", timer.elapsed());
        });
    });
}

fn send_to_channel(id: String, content: String) {
    if !READY.load(Ordering::SeqCst) {
        error!("[send_to_channel] ⚠ This endpoint cannot be accessed before \"pre_init\" has completed");
        return;
    }

    let timer = std::time::Instant::now();
    trace!("[send_to_channel] id: {:?} - content: {:?}", id, content);

    std::thread::spawn(move || {
        TOKIO_RUNTIME.block_on(async {
            let message = Message::new().set_type(Type::Call).set_data(Data::from([
                ("function_name".to_owned(), json!("send_to_channel")),
                ("id".to_owned(), json!(id)),
                ("content".to_owned(), json!(content)),
            ]));

            if let Err(e) = BotRequest::send(message) {
                error!("[send_to_channel] ❌ {}", e);
            };

            info!("[send_to_channel] ⏲ Took {:.2?}", timer.elapsed());
        });
    });
}

fn utc_timestamp() -> String {
    let timestamp = Utc::now().to_rfc3339();
    trace!("[utc_timestamp] - {timestamp}");

    timestamp
}

fn log_level() -> String {
    let log_level = CONFIG.log_level.to_lowercase();
    trace!("[log_level] - {log_level}");

    log_level
}

fn log_output() -> String {
    let log_output = CONFIG.log_output.to_lowercase();
    trace!("[log_output] - {log_output}");

    log_output
}

fn log(log_level: String, caller: String, content: String) {
    let timer = std::time::Instant::now();
    trace!(
        "[log] log_level: {:?} - caller: {:?} - content size: {:?} bytes",
        log_level,
        caller,
        content.len()
    );

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

    trace!("[log] ⏲ Took {:.2?}", timer.elapsed());
}

fn number_to_string(input_number: String) -> Result<String, String> {
    // Allow different types of separations
    let locale = match Locale::from_name(&CONFIG.number_locale) {
        Ok(l) => l,
        Err(e) => {
            return Err(format!(
                "[#number_to_string] Failed to local configured locale \"{locale}\". Reason: {e}",
                locale = CONFIG.number_locale
            ))
        }
    };

    match input_number.parse::<usize>() {
        Ok(n) => Ok(n.to_formatted_string(&locale)),
        Err(e) => Err(format!(
            "[#number_to_string] Failed to parse unsigned integer from {input_number}. Reason: {e}"
        )),
    }
}

///////////////////////////////////////////////////////////////////////
// END Arma accessible functions
///////////////////////////////////////////////////////////////////////

#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Init {
    pub extension_version: String,
    pub price_per_object: NumberString,
    pub server_name: String,
    pub server_start_time: DateTime<Utc>,
    pub territory_data: String,
    pub territory_lifetime: NumberString,
    pub vg_enabled: bool,
    pub vg_max_sizes: String,
}

impl Init {
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = vec![];

        if self.extension_version.is_empty() {
            errors.push("\"extension_version\" was not provided".into());
        }

        if let Err(e) = self.price_per_object.parse::<usize>() {
            errors.push(format!(
                "Could not parse \"{}\" provided to \"price_per_object\" - {}",
                self.price_per_object, e
            ));
        }

        if self.server_name.is_empty() {
            errors.push("\"server_name\" was not provided".into());
        }

        if self.territory_data.is_empty() {
            errors.push("\"territory_data\" was not provided".into());
        }

        if let Err(e) = self.territory_lifetime.parse::<usize>() {
            errors.push(format!(
                "Could not parse \"{}\" provided to \"territory_lifetime\" - {}",
                self.territory_lifetime, e
            ));
        }

        if self.vg_max_sizes.is_empty() {
            errors.push("\"vg_max_sizes\" was not provided".into());
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }

    pub fn to_data(&self) -> Data {
        Data::from([
            (
                "extension_version".to_owned(),
                json!(self.extension_version),
            ),
            ("price_per_object".to_owned(), json!(self.price_per_object)),
            ("server_name".to_owned(), json!(self.server_name)),
            (
                "server_start_time".to_owned(),
                json!(self.server_start_time),
            ),
            ("territory_data".to_owned(), json!(self.territory_data)),
            (
                "territory_lifetime".to_owned(),
                json!(self.territory_lifetime),
            ),
            ("vg_enabled".to_owned(), json!(self.vg_enabled)),
            ("vg_max_sizes".to_owned(), json!(self.vg_max_sizes)),
        ])
    }
}

#[cfg(test)]
mod tests {
    use super::init;
    use regex::Regex;

    #[test]
    fn it_returns_current_timestamp() {
        let extension = init().testing();
        let (result, _) = extension.call("utc_timestamp", None);

        // "2021-01-01T00:00:00.000000000+00:00"
        let re =
            Regex::new(r#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}\+\d{2}:\d{2}$"#).unwrap();

        assert!(re.is_match(&result));
    }

    #[test]
    fn it_returns_log_level() {
        let extension = init().testing();
        let (result, _) = extension.call("log_level", None);
        assert_eq!(result, "info");
    }
}
