//! Updater configuration loaded from `@esm/config.yml`.
//!
//! Mirrors the style of `src/esm/src/config.rs`: reads the YAML file,
//! falls back to `Config::default()` on missing or parse errors, and
//! uses per-field default functions with `#[serde(default = "...")]`.

use serde::{Deserialize, Serialize};

/// Runtime configuration for the updater.
///
/// All fields have sensible defaults so a missing or partial `config.yml`
/// still produces a working configuration.
#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Config {
    /// Whether the auto-updater is enabled at all.
    /// Setting to `false` causes `run_boot_check` to return `Disabled`
    /// immediately without making any network requests.
    #[serde(default = "default_updater_enabled")]
    pub updater_enabled: bool,

    /// URL of the JSON version manifest.
    /// A detached signature is expected at `{url}.sig`.
    #[serde(default = "default_updater_url")]
    pub updater_url: String,

    /// Maximum milliseconds to spend on the entire boot-check network path.
    /// Applies as a shared deadline across manifest fetch + artifact download.
    #[serde(default = "default_updater_timeout_ms")]
    pub updater_timeout_ms: u64,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            updater_enabled: default_updater_enabled(),
            updater_url: default_updater_url(),
            updater_timeout_ms: default_updater_timeout_ms(),
        }
    }
}

fn default_updater_enabled() -> bool {
    true
}

fn default_updater_url() -> String {
    "https://esmbot.com/versions.json".into()
}

fn default_updater_timeout_ms() -> u64 {
    800
}

impl Config {
    /// Load config from `@esm/config.yml` relative to cwd.
    ///
    /// Falls back to `Config::default()` if the file is missing or
    /// fails to parse, so the caller never needs to handle a hard error
    /// just because the config file isn't there yet.
    pub fn new() -> Self {
        let contents = match std::fs::read_to_string("@esm/config.yml") {
            Ok(s) => s,
            Err(_) => {
                log::info!("[config::new] default config loaded");
                return Config::default();
            }
        };

        match serde_yaml::from_str(&contents) {
            Ok(cfg) => cfg,
            Err(e) => {
                log::error!(
                    "[config::new] failed to parse @esm/config.yml: {}",
                    e
                );
                Config::default()
            }
        }
    }

    /// Override the manifest URL with the CLI `--manifest-url` flag value.
    ///
    /// Returns `self` unchanged when `url` is `None`, making it ergonomic to
    /// chain directly from the flag option: `Config::new().with_manifest_url(opt)`.
    pub fn with_manifest_url(mut self, url: Option<String>) -> Self {
        if let Some(u) = url {
            self.updater_url = u;
        }
        self
    }
}
