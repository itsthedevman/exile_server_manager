use crate::a3_post_server_initialization;
use crate::command::*;
use chrono::Utc;
use log::*;
use serde_json::json;
use std::sync::RwLock;

pub struct ArmaServer {
    id: RwLock<String>,
    max_payment_count: RwLock<i64>,
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        ArmaServer {
            id: RwLock::new(String::from("")),
            max_payment_count: RwLock::new(0),
        }
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
                warn!("[ArmaServer::post_initialization] Failed to gain write lock for id attribute. Reason: {:?}", e);
            }
        }

        // Stores the max_payment_count
        match self.max_payment_count.try_write() {
            Ok(mut count) => {
                *count = parameters.max_payment_count;
            }
            Err(e) => {
                warn!("[ArmaServer::post_initialization] Failed to gain write lock for max_payment_count attribute. Reason: {:?}", e);
            }
        }

        a3_post_server_initialization(&command, parameters);

        crate::BOT.send(
            Some(command.id.clone()),
            command.command_name.clone(),
            json!({ "_event": "after_execute", "_event_parameters": json!({ "timestamp": Utc::now().timestamp() }).to_string() }).to_string(),
        );
    }
}
