use crate::{database::Database};
use crate::command::*;
use chrono::Utc;

use log::*;
use serde_json::json;

pub struct ArmaServer {
    pub id: String,
    pub max_payment_count: i64,
    pub server_initialization_package: Option<String>,
    database: Database,
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        ArmaServer {
            id: String::from(""),
            max_payment_count: 0,
            database: Database::new(),
            server_initialization_package: None
        }
    }

    pub fn extdb_version(&self) -> u8 {
        self.database.extdb_version
    }

    pub fn server_initialization(&self, command: &Command) {
        match &self.server_initialization_package {
            Some(val) => {
                crate::BOT.send(Some(command.id.clone()), command.command_name.clone(), val.clone());
            }
            _ => {
                error!("[arma_server::server_initialization] Requested server initialization before anything has been stored. ESM_fnc_preInit must be called first.");
            },
        };
    }

    pub fn post_initialization(&mut self, command: &Command) {
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

        crate::a3_post_server_initialization(command, parameters, self.extdb_version());
    }

    pub fn reward(&self, command: &Command) {
        let parameters: &Reward = match command.parameters {
            Parameters::Reward(ref val) => val,
            _ => {
                error!("[arma_server::reward] Failed to retrieve parameters. Parameters was parsed as {:?}", command.parameters);
                return;
            }
        };

        // Check to make sure the user who is executing this command has joined this server
        if !self.database.account_exists(&parameters.target_uid) {
            return command.reply_with_error_code("account_does_not_exist");
        }
    }
}
