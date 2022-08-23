use crate::*;
use serde::{Deserialize, Serialize};

/// Represents the esm.key file
#[derive(Serialize, Deserialize, Debug, Default, Clone)]
pub struct Token {
    pub id: Vec<u8>,
    pub key: Vec<u8>,

    #[serde(skip)]
    pub server_id: String,

    #[serde(skip)]
    pub community_id: String,
}

impl Token {
    pub fn update_from(&mut self, token: Token) -> &mut Self {
        self.id = token.id;
        self.key = token.key;

        self.server_id = match String::from_utf8(self.id.clone()) {
            Ok(s) => s,
            Err(e) => {
                error!("[token#server_id] Failed to parse server ID. Reason: {e}");
                String::new()
            }
        };

        // 95 is _
        let split_index = self.id.iter().position(|byte| *byte == 95).unwrap();
        self.community_id = match String::from_utf8(self.id[0..split_index].to_vec()) {
            Ok(s) => s,
            Err(e) => {
                error!("[token#community_id] Failed to parse community ID. Reason: {e}");
                String::new()
            }
        };

        self
    }

    pub fn valid(&self) -> bool {
        !self.id.is_empty()
            && !self.key.is_empty()
            && !self.server_id.is_empty()
            && !self.community_id.is_empty()
    }
}

impl std::fmt::Display for Token {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Token {{ server_id: {:?}, community_id: {:?}, valid: {} }}",
            self.server_id,
            self.community_id,
            self.valid()
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_token() {
        let token = Token {
            id: "esm_malden".as_bytes().to_vec(),
            key: "12345".as_bytes().to_vec(),
            server_id: String::new(),
            community_id: String::new(),
        };

        assert!(!token.valid());

        let mut new_token = token.clone();
        new_token.update_from(token);

        assert_eq!(new_token.community_id, "esm".to_string());
        assert_eq!(new_token.server_id, "esm_malden".to_string());

        assert!(new_token.valid());
    }
}
