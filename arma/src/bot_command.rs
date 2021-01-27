use serde::{Deserialize, Serialize};
use log::*;

#[derive(Serialize, Deserialize, Clone)]
pub struct BotCommand {
    id: Option<String>,
    command_name: String,
    parameters: String,
}

impl BotCommand {
    pub fn new(id: Option<String>, command_name: String, parameters: String) -> BotCommand {
        BotCommand { id, command_name, parameters }
    }

    pub fn into_json(&self) -> String {
        match serde_json::to_string(&self) {
            Ok(val) => val,
            Err(e) => {
                error!(
                    "Failed to convert command to JSON. Reason: {:?} id: {:?}, command_name: {}, parameters: {}",
                    e, self.id, self.command_name, self.parameters
                );
                String::from("{}")
            }
        }
    }
}
