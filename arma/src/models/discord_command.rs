use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize)]
pub struct DiscordCommand {
    id: Option<String>,
    command_name: String,
    package: String,
}

impl DiscordCommand {
    pub fn new<S>(command_name: S, package: String) -> DiscordCommand
    where
        S: Into<String>,
    {
        // Clean up the array sent from Arma3
        let package = str::replace(&package, "\"\"", "\"");

        DiscordCommand {
            id: None,
            command_name: command_name.into(),
            package,
        }
    }

    pub fn new_with_id<S>(id: String, command_name: S, package: String) -> DiscordCommand
    where
        S: Into<String>,
    {
        // Clean up the array sent from Arma3
        let package = str::replace(&package, "\"\"", "\"");

        DiscordCommand {
            id: Some(id),
            command_name: command_name.into(),
            package,
        }
    }

    pub fn into_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(&self)
    }
}
