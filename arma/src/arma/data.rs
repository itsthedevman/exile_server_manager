use arma_rs::{ArmaValue, arma_value, ToArma};
use serde::{Deserialize, Serialize};
use uuid::Uuid;

/// Represents the esm.key file
#[derive(Serialize, Deserialize, Debug)]
pub struct Token {
    pub id: Vec<u8>,
    pub key: Vec<u8>,
}

impl Token {
    pub fn new(id: Vec<u8>, key: Vec<u8>) -> Self {
        Token { id, key }
    }

    pub fn server_id(&self) -> String {
        String::from_utf8(self.id.clone()).expect("[token::server_id] Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).")
    }

    pub fn community_id(&self) -> String {
        // 95 is _
        let split_index = self.id.iter().position(|byte| *byte == 95).unwrap();
        String::from_utf8(self.id[0..split_index].to_vec()).expect("[token::server_id] Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).")
    }
}

impl std::fmt::Display for Token {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "Token {{ id: {}, key: {} }}", String::from_utf8_lossy(&self.id), String::from_utf8_lossy(&self.key))
    }
}

#[derive(Debug)]
pub struct RVOutput {
    pub id: Option<Uuid>,
    pub code: isize,
    pub content: ArmaValue,
}

impl RVOutput {
    pub fn new(id: Option<Uuid>, code: isize, content: ArmaValue) -> Self {
        RVOutput { id, code, content }
    }
}

impl std::fmt::Display for RVOutput {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}", arma_value!([self.id, self.code, self.content]))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_community_id() {
        let token = Token::new(
            "esm_malden".as_bytes().to_vec(),
            "12345".as_bytes().to_vec(),
        );
        assert_eq!(token.community_id(), "esm".to_string());
    }
}
