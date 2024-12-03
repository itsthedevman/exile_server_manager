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

mod arma;
mod bot;
mod config;
mod database;
mod encryption;
mod endpoints;
mod error;
mod log_search;
mod macros;
mod message;
mod parser;
mod request;
mod router;
mod token;

pub use arma::DATABASE;
pub use bot::TOKEN_MANAGER;
use config::Config;
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
    // This will create a log file in the src directory when running tests
    if !cfg!(test) {
        // Start the logger
        initialize_logger();
    }

    debug!("[init] - Initializing");

    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);

    endpoints::register()
}

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
        let re = Regex::new(
            r#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}\+\d{2}:\d{2}$"#,
        )
        .unwrap();

        assert!(re.is_match(&result));
    }

    #[test]
    fn it_returns_log_level() {
        let extension = init().testing();
        let (result, _) = extension.call("log_level", None);
        assert_eq!(result, "info");
    }
}
