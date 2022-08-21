use log::error;
use serde::{Deserialize, Serialize};

/// Represents the esm.key file
#[derive(Serialize, Deserialize, Debug, Default, Clone)]
pub struct Token {
    pub id: Vec<u8>,
    pub key: Vec<u8>,
}

impl Token {
    pub fn new(id: Vec<u8>, key: Vec<u8>) -> Self {
        Token { id, key }
    }

    pub fn server_id(&self) -> Option<String> {
        match String::from_utf8(self.id.clone()) {
            Ok(s) => Some(s),
            Err(e) => {
                error!("[token#server_id] Failed to parse server ID. Reason: {e}");
                None
            }
        }
    }

    pub fn community_id(&self) -> Option<String> {
        // 95 is _
        let split_index = self.id.iter().position(|byte| *byte == 95).unwrap();
        match String::from_utf8(self.id[0..split_index].to_vec()) {
            Ok(s) => Some(s),
            Err(e) => {
                error!("[token#community_id] Failed to parse community ID. Reason: {e}");
                None
            }
        }
    }

    pub fn valid(&self) -> bool {
        !self.id.is_empty()
            && !self.key.is_empty()
            && self.server_id().is_some()
            && self.community_id().is_some()
    }
}

impl std::fmt::Display for Token {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "Token {{ id: {}, key: {} }}",
            String::from_utf8_lossy(&self.id),
            String::from_utf8_lossy(&self.key)
        )
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
        assert_eq!(token.community_id(), Some("esm".to_string()));
    }
}
