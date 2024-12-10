use crate::*;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Config {
    #[serde(default = "default_connection_uri")]
    pub connection_uri: String,

    #[serde(default = "default_logging_path")]
    pub logging_path: String,

    #[serde(default = "default_log_level")]
    pub log_level: String,

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

    #[serde(default = "default_number_locale")]
    pub number_locale: String,

    #[serde(default = "default_exile_logs_search_days")]
    pub exile_logs_search_days: u32,

    #[serde(default = "default_additional_logs")]
    pub additional_logs: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Config {
            connection_uri: default_connection_uri(),
            logging_path: default_logging_path(),
            log_level: default_log_level(),
            extdb_conf_path: default_extdb_conf_path(),
            extdb_conf_header_name: default_extdb_conf_header_name(),
            extdb_version: default_extdb_version(),
            log_output: default_log_output(),
            database_uri: default_database_uri(),
            server_mod_name: default_server_mod_name(),
            number_locale: default_number_locale(),
            exile_logs_search_days: default_exile_logs_search_days(),
            additional_logs: default_additional_logs(),
        }
    }
}

fn default_connection_uri() -> String {
    "arma.esmbot.com:2035".into()
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

fn default_extdb_conf_path() -> String {
    String::default()
}

fn default_extdb_conf_header_name() -> String {
    "exile".into()
}

fn default_extdb_version() -> u8 {
    3
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

fn default_number_locale() -> String {
    String::from("en")
}

fn default_exile_logs_search_days() -> u32 {
    14
}

fn default_additional_logs() -> Vec<String> {
    Vec::new()
}

impl std::fmt::Display for Config {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{:#?}", self)
    }
}

type ConfigResult = Result<(), String>;

impl Config {
    pub fn new() -> Self {
        let contents: String = match fs::read_to_string("@esm/config.yml") {
            Ok(file) => file,
            Err(_) => {
                info!("[new] ✅ Default config loaded");
                return Config::default();
            }
        };

        match serde_yaml::from_str(&contents) {
            Ok(config) => config,
            Err(e) => {
                error!("[new] ❌ Failed to parse @esm/config.yml - {}", e);
                Config::default()
            }
        }
    }

    pub fn validate(&self) -> ConfigResult {
        self.validate_connection_url()?;
        self.validate_number_locale()
    }

    fn validate_connection_url(&self) -> ConfigResult {
        match std::net::ToSocketAddrs::to_socket_addrs(&self.connection_uri) {
            Ok(mut addr) => match addr.next() {
                Some(_socket_addr) => Ok(()),
                None => Err(format!(
                    "Failed to convert connection url -> {:?}",
                    self.connection_uri
                )),
            },
            Err(e) => Err(format!(
                "Failed to parse connection url -> {:?}. Reason: {}",
                self.connection_uri, e
            )),
        }
    }

    fn validate_number_locale(&self) -> ConfigResult {
        match Locale::from_name(&self.number_locale) {
            Ok(_) => Ok(()),
            Err(e) => Err(format!(
                "Failed to validate number_locale -> {:?}. Reason: {}",
                self.number_locale, e
            )),
        }
    }
}
