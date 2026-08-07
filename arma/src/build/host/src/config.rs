use std::path::Path;

use serde::{Deserialize, Serialize};

use crate::error::BuildError;

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct Config {
    pub server: ServerConfig,
    pub my_steam_uid: String,
    pub instances: Vec<Instance>,
}

#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct ServerConfig {
    pub steam_password: String,
    pub steam_user: String,
    pub mysql_uri: String,
    pub server_args: Vec<String>,
}

/// One Arma 3 server: its own container, game port, Exile database, and ESM server key.
///
/// `server_id` is the ESM server's own identifier (`esm_malden`), not a separate build-side name. Every other
/// address this server needs is derived from it, so declaring one is three lines of config and nothing else.
#[derive(Default, Serialize, Deserialize, Debug, Clone)]
pub struct Instance {
    pub server_id: String,
    pub port: u16,
    pub database: String,
}

/// Ports an Arma 3 server claims above its game port: Steam query (+1), Steam master (+2), and headroom.
const PORT_SPAN: u16 = 4;

impl Instance {
    pub fn container(&self) -> String {
        format!("ESM_ARMA_{}", self.server_id.to_uppercase())
    }

    pub fn compose_project(&self) -> String {
        format!("esm_arma_{}", self.server_id)
    }

    pub fn last_port(&self) -> u16 {
        self.port + PORT_SPAN
    }
}

pub fn parse(path: &Path) -> Result<Config, BuildError> {
    let contents = std::fs::read_to_string(path).map_err(|e| {
        BuildError::Config(format!(
            "{e} — Could not read config.yml. Have you created/symlinked it?"
        ))
    })?;

    let config: Config = serde_yaml::from_str(&contents).map_err(|e| {
        BuildError::Config(format!("Failed to parse config.yml: {e}"))
    })?;

    validate(&config)?;
    Ok(config)
}

fn validate(config: &Config) -> Result<(), BuildError> {
    if config.instances.is_empty() {
        return Err(BuildError::Config(
            "config.yml declares no servers. Add at least one entry under `instances:` with a server_id \
             (matching an ESM server, e.g. esm_malden), a port, and a database."
                .into(),
        ));
    }

    for (index, instance) in config.instances.iter().enumerate() {
        if let Some(duplicate) = config.instances[..index]
            .iter()
            .find(|other| other.server_id == instance.server_id)
        {
            return Err(BuildError::Config(format!(
                "Two `instances` entries share the server_id '{}'. Each entry must name a different ESM \
                 server, since the server_id decides the container, volumes, and server key.",
                duplicate.server_id
            )));
        }

        if let Some(overlap) = config.instances[..index]
            .iter()
            .find(|other| instance.port <= other.last_port() && other.port <= instance.last_port())
        {
            return Err(BuildError::Config(format!(
                "Servers '{}' (port {}) and '{}' (port {}) claim overlapping port ranges. Arma uses the game \
                 port through +{PORT_SPAN}, so give them ports at least {} apart.",
                overlap.server_id,
                overlap.port,
                instance.server_id,
                instance.port,
                PORT_SPAN + 1
            )));
        }
    }

    Ok(())
}
