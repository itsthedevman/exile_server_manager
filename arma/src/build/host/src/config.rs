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
    #[serde(default)]
    pub arma_binary: String,

    #[serde(default)]
    pub arma_cdlc: String,

    #[serde(default)]
    pub arma_config: String,

    #[serde(default)]
    pub arma_limitfps: String,

    #[serde(default)]
    pub arma_params: String,

    #[serde(default)]
    pub arma_profile: String,

    #[serde(default)]
    pub arma_world: String,

    #[serde(default)]
    pub headless_clients_profile: String,

    #[serde(default)]
    pub headless_clients: String,

    #[serde(default)]
    pub mods_local: String,

    #[serde(default)]
    pub mods_preset: String,

    #[serde(default)]
    pub port: String,

    #[serde(default)]
    pub skip_install: String,

    #[serde(default)]
    pub steam_branch_password: String,

    #[serde(default)]
    pub steam_branch: String,

    // Required
    pub steam_password: String,
    pub steam_user: String,
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
