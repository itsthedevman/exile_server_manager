use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Clone)]
pub struct BotCommand {
    id: Option<String>,
    command_name: String,
    package: String,
}

impl BotCommand {
    pub fn new<S>(command_name: S, package: String) -> BotCommand
    where
        S: Into<String>,
    {
        // Clean up the array sent from Arma3
        let package = str::replace(&package, "\"\"", "\"");

        BotCommand {
            id: None,
            command_name: command_name.into(),
            package,
        }
    }

    pub fn new_with_id<S>(id: String, command_name: S, package: String) -> BotCommand
    where
        S: Into<String>,
    {
        // Clean up the array sent from Arma3
        let package = str::replace(&package, "\"\"", "\"");

        BotCommand {
            id: Some(id),
            command_name: command_name.into(),
            package,
        }
    }

    pub fn into_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(&self)
    }
}
