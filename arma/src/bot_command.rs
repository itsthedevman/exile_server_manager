use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use anyhow::{bail, Result};

#[derive(Serialize, Deserialize, Clone)]
pub struct BotCommand {
    id: Option<String>,
    command_name: String,
    parameters: Vec<Value>,
}


// fn convert_a3_array(array_string: &String) -> Result<Vec<Value>> {
//     // Arma uses double quotes for escaping double quotes
//     let package = str::replace(&array_string, r#""""#, r#"""#);
//     let package: Vec<Value> = serde_json::from_str(&package)?;
//     let parameters = BotParameters::new(package);

//     Ok(parameters.parse())
// }

impl BotCommand {
    pub fn new<S>(command_name: S, package: &String) -> Result<BotCommand>
    where
        S: Into<String>,
    {
        let command = BotCommand {
            id: None,
            command_name: command_name.into(),
            parameters: vec![],
        };

        Ok(command)
    }

    // pub fn new_with_id<S>(id: String, command_name: S, package: &String) -> Result<BotCommand>
    // where
    //     S: Into<String>,
    // {
    //     let command = BotCommand {
    //         id: Some(id),
    //         command_name: command_name.into(),
    //         parameters: convert_a3_array(&package)?,
    //     };

    //     Ok(command)
    // }

    pub fn into_json(&self) -> Result<String, serde_json::Error> {
        serde_json::to_string(&self)
    }
}
