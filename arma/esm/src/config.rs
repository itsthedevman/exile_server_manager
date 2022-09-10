use crate::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Config {
    #[serde(default = "default_connection_url")]
    pub connection_url: String,

    #[serde(default = "default_logging_path")]
    pub logging_path: String,

    #[serde(default = "default_log_level")]
    pub log_level: String,

    #[serde(default = "default_env")]
    pub env: Env,

    #[serde(default = "default_extdb_conf_path")]
    pub extdb_conf_path: String,

    #[serde(default = "default_extdb_conf_header_name")]
    pub extdb_conf_header_name: String,

    #[serde(default = "default_extdb_version")]
    pub extdb_version: u8,

    #[serde(default = "default_log_output")]
    pub log_output: String,

    #[serde(default = "default_database_uri")]
    pub database_uri: String,

    #[serde(default = "default_server_mod_name")]
    pub server_mod_name: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, Copy)]
#[serde(rename_all = "lowercase")]
pub enum Env {
    Production,
    Test,
    Development,
}

impl Env {
    pub fn production(&self) -> bool {
        matches!(self, Env::Production)
    }

    pub fn test(&self) -> bool {
        matches!(self, Env::Test)
    }

    pub fn development(&self) -> bool {
        matches!(self, Env::Development)
    }
}

fn default_connection_url() -> String {
    "https://arma.esmbot.com".into()
}

fn default_logging_path() -> String {
    match std::env::current_dir() {
        Ok(mut p) => {
            p.push("@esm");
            p.push("log");
            p.push("esm.log");
            p.to_str().unwrap_or("").to_string()
        }
        Err(_e) => String::new(),
    }
}

fn default_log_level() -> String {
    "info".into()
}

fn default_env() -> Env {
    Env::Production
}

fn default_extdb_conf_path() -> String {
    String::default()
}

fn default_extdb_conf_header_name() -> String {
    "exile".into()
}

fn default_extdb_version() -> u8 {
    0
}

fn default_log_output() -> String {
    "extension".into()
}

fn default_database_uri() -> String {
    String::default()
}

fn default_server_mod_name() -> String {
    if cfg!(windows) {
        "@ExileServer".into()
    } else {
        "@exileserver".into()
    }
}

impl Default for Config {
    fn default() -> Self {
        serde_yaml::from_str("").unwrap()
    }
}

impl std::fmt::Display for Config {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:#?}", self)
    }
}

impl Config {
    pub fn new() -> Self {
        let contents: String = match fs::read_to_string("@esm/config.yml") {
            Ok(file) => file,
            Err(_) => {
                info!("[config#new] ✅ Default config loaded");
                return Config::default();
            }
        };

        match serde_yaml::from_str(&contents) {
            Ok(config) => config,
            Err(e) => {
                error!("[config#new] ❌ Failed to parse @esm/config.yml - {}", e);
                Config::default()
            }
        }
    }

    pub fn validate(&self) -> Result<(), String> {
        self.validate_connection_url()
    }

    fn validate_connection_url(&self) -> Result<(), String> {
        match std::net::ToSocketAddrs::to_socket_addrs(&self.connection_url) {
            Ok(mut addr) => match addr.next() {
                Some(_socket_addr) => Ok(()),
                None => Err(format!(
                    "Failed to convert connection url -> {:?}",
                    self.connection_url
                )),
            },
            Err(e) => Err(format!(
                "Failed to parse connection url -> {:?}. Reason: {}",
                self.connection_url, e
            )),
        }
    }
}
