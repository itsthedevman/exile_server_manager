use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug)]
pub struct ArmaRequest {
    function: String,
    parameters: HashMap<String, String>
}

impl ArmaRequest {
    // A request from the Arma 3 server to the extension
    pub fn new(function: String, parameters: HashMap<String, String>) -> ArmaRequest {
        ArmaRequest { function, parameters }
    }
}
