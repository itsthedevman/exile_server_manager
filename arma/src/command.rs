use std::collections::HashMap;
use serde::{Deserialize, Serialize};
use serde_json::Value;

#[derive(Serialize, Deserialize)]
pub struct Command {
  pub id: String,
  pub command_name: String,
  pub parameters: HashMap<String, Value>,
  pub metadata: HashMap<String, Value>
}
