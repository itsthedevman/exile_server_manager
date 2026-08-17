#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

//! Arma 3 extension wrapper for the ESM auto-updater.
//!
//! This crate is a thin cdylib shim. All update logic lives in `updater_lib`.
//! The extension exposes one command — `check_update` — which is called from
//! SQF during `preInit` before `exile_server_manager` loads `esm.dll/.so`.

use arma_rs::{arma, Extension};
use lazy_static::lazy_static;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;
use updater_lib::config::Config;

mod endpoints;

lazy_static! {
    /// Updater configuration, loaded once from `@esm/config.yml`.
    /// Falls back to defaults if the file is missing or unparseable.
    pub static ref CONFIG: Config = Config::new();
}

fn initialize_logger() {
    let log_pattern = "[{d(%Y-%m-%d %H:%M:%S%.3f)(utc)}Z {h({l})} {M}:{L}] {m}{n}";

    let logfile = match FileAppender::builder()
        .encoder(Box::new(PatternEncoder::new(log_pattern)))
        .build(&CONFIG.log_path)
    {
        Ok(f) => f,
        Err(e) => {
            println!("[ESM Updater] failed to create log file at {}: {e}", CONFIG.log_path);
            return;
        }
    };

    let log_config = match LogConfig::builder()
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(Root::builder().appender("logfile").build(log::LevelFilter::Info))
    {
        Ok(c) => c,
        Err(e) => {
            println!("[ESM Updater] failed to build log config: {e}");
            return;
        }
    };

    if let Err(e) = log4rs::init_config(log_config) {
        println!("[ESM Updater] failed to init logger: {e}");
    }
}

#[arma]
pub fn init() -> Extension {
    if !cfg!(test) {
        initialize_logger();
    }

    lazy_static::initialize(&CONFIG);

    log::info!(
        "[init] ESM Updater v{} initializing, verifying against the {}",
        env!("CARGO_PKG_VERSION"),
        updater_lib::verification_key_label()
    );

    endpoints::register()
}
