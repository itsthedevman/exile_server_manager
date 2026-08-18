#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)]

//! Arma 3 extension wrapper for the ESM auto-updater.
//!
//! This crate is a thin cdylib shim. All update logic lives in `updater_lib`.
//! The extension exposes one command — `check_update` — which is called from
//! SQF during `preInit` before `exile_server_manager` loads `esm.dll/.so`.

use arma_rs::{Extension, arma};
use lazy_static::lazy_static;
use updater_lib::config::Config;

mod endpoints;

lazy_static! {
    /// Updater configuration, loaded once from `@esm/config.yml`.
    /// Falls back to defaults if the file is missing or unparseable.
    pub static ref CONFIG: Config = Config::new();
}

#[arma]
pub fn init() -> Extension {
    if !cfg!(test) {
        updater_lib::logging::initialize(&CONFIG.updater_log_path);
    }

    lazy_static::initialize(&CONFIG);

    log::info!(
        "[init] ESM Updater v{} initializing, verifying against the {}",
        env!("CARGO_PKG_VERSION"),
        updater_lib::verification_key_label()
    );

    endpoints::register()
}
