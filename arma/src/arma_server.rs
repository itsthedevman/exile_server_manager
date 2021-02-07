use crate::{a3_post_server_initialization, database::Database};
use crate::command::*;
use chrono::Utc;

use log::*;
use serde_json::json;

pub struct ArmaServer {
    pub id: String,
    pub max_payment_count: i64,
    database: Database,
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        ArmaServer {
            id: String::from(""),
            max_payment_count: 0,
            database: Database::new(),
        }
    }

    pub fn extdb_version(&self) -> u8 {
        self.database.extdb_version
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

    pub fn post_initialization(&mut self, command: Command) {
        let parameters: &ServerPostInitialization = match command.parameters {
            Parameters::ServerPostInitialization(ref val) => val,
            _ => {
                error!("[arma_server::post_initialization] Failed to retrieve parameters. Parameters was parsed as {:?}", command.parameters);
                return;
            }
        };

        // Stores the server_id
        self.id = parameters.server_id.clone();

        // Stores the max_payment_count
        self.max_payment_count = parameters.max_payment_count;

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
