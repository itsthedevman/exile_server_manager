use std::{collections::HashMap, fmt};
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
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
    pub extdb_version: u8
}

#[derive(Serialize, Deserialize, Debug)]
#[serde(rename_all = "lowercase")]
pub enum Env {
    Production,
    Test,
    Development
}

impl fmt::Display for Env {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        write!(f, "{:?}", serde_json::to_string(self).unwrap())
    }
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
    "arma.esmbot.com".into()
}

fn default_logging_path() -> String {
    "@esm/log/esm.log".into()
}

fn default_log_level() -> String {
    "info".into()
}

fn default_env() -> Env {
    Env::Production
}

fn default_extdb_conf_path() -> String {
    "".into()
}

fn default_extdb_conf_header_name() -> String {
    "exile".into()
}

fn default_extdb_version() -> u8 {
    0
}

impl Config {
    pub fn new() -> Self {
        Config {
            connection_url: default_connection_url(),
            logging_path: default_logging_path(),
            log_level: default_log_level(),
            env: default_env(),
            extdb_conf_path: default_extdb_conf_path(),
            extdb_conf_header_name: default_extdb_conf_header_name(),
            extdb_version: default_extdb_version(),
        }
    }

    pub fn to_hashmap(&self) -> HashMap<&str, String> {
        let mut hash = HashMap::new();

        hash.insert("connection_url", self.connection_url.clone());
        hash.insert("logging_path", self.logging_path.clone());
        hash.insert("log_level", self.log_level.clone());

        hash
    }
}

impl Default for Config {
    fn default() -> Self {
        Config::new()
    }
}
