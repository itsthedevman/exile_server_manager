use std::{collections::HashMap};
use serde::{Serialize, Deserialize};

#[derive(Serialize, Deserialize, Debug)]
pub struct Config {
    #[serde(default = "default_connection_url")]
    pub connection_url: String,

    #[serde(default = "default_logging_path")]
    pub logging_path: String,

    #[serde(default = "default_log_level")]
    pub log_level: String,
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

impl Config {
    pub fn new() -> Self {
        Config {
            connection_url: default_connection_url(),
            logging_path: default_logging_path(),
            log_level: default_log_level(),
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
