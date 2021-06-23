use serde::{Serialize, Deserialize};

/// Represents the esm.key file
#[derive(Serialize, Deserialize, Debug)]
pub struct Token {
    pub id: Vec<u8>,
    pub key: Vec<u8>
}

impl Token {
    pub fn new(id: Vec<u8>, key: Vec<u8>) -> Self {
        Token { id, key }
    }
}
