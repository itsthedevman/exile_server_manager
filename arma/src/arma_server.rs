use crate::{a3_post_server_initialization, database::Database};
use crate::command::*;
use chrono::Utc;

use log::*;
use serde_json::json;
use std::{sync::RwLock};

pub struct ArmaServer {
    pub id: RwLock<String>,
    pub max_payment_count: RwLock<i64>,
    database: Database,
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        ArmaServer {
            id: RwLock::new(String::from("")),
            max_payment_count: RwLock::new(0),
            database: Database::new(),
        }
    }

    pub fn extdb_version(&self) -> u8 {
        *self.database.extdb_version.read().unwrap()
    }

    pub fn server_initialization(&self, command: Command) {
        let metadata = crate::METADATA.read().unwrap();
        let package = metadata.get("server_initialization");
        match package {
            Some(val) => {
                crate::BOT.send(Some(command.id), command.command_name, val.clone());
            }
            _ => (),
        };
    }

    pub fn post_initialization(&self, command: Command) {
        let parameters: &ServerPostInitialization = match command.parameters {
            Parameters::ServerPostInitialization(ref val) => val,
            _ => {
                error!("[arma_server::post_initialization] Failed to retrieve parameters. Parameters was parsed as {:?}", command.parameters);
                return;
            }
        };

        // Stores the server_id
        match self.id.try_write() {
            Ok(mut id) => {
                *id = parameters.server_id.clone();
            }
            Err(e) => {
                warn!("[arma_server::post_initialization] Failed to gain write lock for id attribute. Reason: {:?}", e);
            }
        }

        // Stores the max_payment_count
        match self.max_payment_count.try_write() {
            Ok(mut count) => {
                *count = parameters.max_payment_count;
            }
            Err(e) => {
                warn!("[arma_server::post_initialization] Failed to gain write lock for max_payment_count attribute. Reason: {:?}", e);
            }
        }

        // Get the base path to figure out where to look for the ini
        let base_ini_path = if parameters.extdb_path.is_empty() { String::from("@ExileServer") } else { parameters.extdb_path.clone() };

        // Connect to the database
        self.database.connect(base_ini_path);

        a3_post_server_initialization(&command, parameters);

        crate::BOT.send(
            Some(command.id.clone()),
            command.command_name.clone(),
            json!({ "_event": "after_execute", "_event_parameters": json!({ "timestamp": Utc::now().timestamp() }).to_string() }).to_string(),
        );
    }
}
