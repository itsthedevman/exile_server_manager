use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::BuildError;

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct Config {
    pub server: ServerConfig,
    pub my_steam_uid: String,
    pub mysql_database_name: String,
}

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct ServerConfig {
    pub steam_password: String,
    pub steam_user: String,
    pub mysql_uri: String,
    pub server_args: Vec<String>,
}

pub fn parse(path: &Path) -> Result<Config, BuildError> {
    let contents = std::fs::read_to_string(path).map_err(|e| {
        BuildError::Config(format!(
            "{e} — Could not read config.yml. Have you created/symlinked it?"
        ))
    })?;

    serde_yaml::from_str(&contents).map_err(|e| {
        BuildError::Config(format!("Failed to parse config.yml: {e}"))
    })
}
