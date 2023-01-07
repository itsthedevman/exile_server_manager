use std::path::PathBuf;

use common::BuildError;
use serde::{Deserialize, Serialize};

#[derive(Default, Serialize, Deserialize, Debug, Clone)]

pub struct Config {
    pub server: ServerConfig,
    pub my_steam_uid: String,
    pub steam_uids: Vec<String>,
}

#[derive(Default, Serialize, Deserialize, Debug, Clone)]

pub struct ServerConfig {
    pub steam_password: String,
    pub steam_user: String,
    pub mysql_uri: String,
    pub server_args: Vec<String>,
}

pub fn parse(path: PathBuf) -> Result<Config, BuildError> {
    let contents = match std::fs::read_to_string(path) {
        Ok(c) => c,
        Err(e) => {
            return Err(format!(
                "{} - Could not find/read config.yml. Have you created/sym linked it yet?",
                e
            )
            .into())
        }
    };

    match serde_yaml::from_str(&contents) {
        Ok(c) => Ok(c),
        Err(e) => Err(e.to_string().into()),
    }
}
