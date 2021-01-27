use crate::command::Command;
use std::{sync::RwLock};
use log::*;

pub struct ArmaServer {
    id: RwLock<String>
}

impl ArmaServer {
    pub fn new() -> ArmaServer {
        ArmaServer { id: RwLock::new(String::from("")) }
    }

    pub fn server_initialization(&self, command: Command) {
        let metadata = crate::METADATA.read().unwrap();
        let package = metadata.get("server_initialization");
        match package {
            Some(val) => {
                crate::BOT.send(Some(command.id), command.command_name, val.clone());
            },
            _ => ()
        };
    }

    pub fn post_initialization(&self, command: Command) {
        // Stores the server_id
        // Attempt to gain write access to ID
        match self.id.try_write() {
            Ok(mut id) => {
                // Attempt to retrieve the server_id attribute
                match command.parameters.get("server_id") {
                    Some(server_id) => {
                        // Attempt to load that attribute as a &str
                        match server_id.as_str() {
                            Some(val) => {
                                // Finally, set the value
                                *id = String::from(val)
                            },
                            None => warn!("[ArmaServer::post_initialization] Unable to retrieve String from parameter: server_id")
                        }
                    },
                    None => warn!("[ArmaServer::post_initialization] Missing parameter: server_id")
                }
            },
            Err(e) => {
                warn!("[ArmaServer::post_initialization] Failed to gain write lock for id attribute. Reason: {:?}", e);
            }
        }
    }
}
