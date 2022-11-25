use std::{fs::File, io::Read};

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
                error!("[server_id] ❌ Failed to parse server ID. Reason: {e}");
                String::new()
            }
        };

        // 95 is _
        let split_index = self.id.iter().position(|byte| *byte == 95).unwrap();
        self.community_id = match String::from_utf8(self.id[0..split_index].to_vec()) {
            Ok(s) => s,
            Err(e) => {
                error!("[community_id] ❌ Failed to parse community ID. Reason: {e}");
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
        f.debug_struct("Token")
            .field("server_id", &self.server_id)
            .field("community_id", &self.community_id)
            .field("valid", &self.valid())
            .finish()
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

#[derive(Default, Clone)]
pub struct TokenManager {
    token: Token,
}

impl TokenManager {
    pub fn new() -> Self {
        TokenManager::default()
    }

    pub fn valid(&self) -> bool {
        self.token.valid()
    }

    pub fn id_bytes(&self) -> &[u8] {
        &self.token.id
    }

    pub fn key_bytes(&self) -> &[u8] {
        &self.token.key
    }

    pub fn server_id(&self) -> &str {
        &self.token.server_id
    }

    pub fn community_id(&self) -> &str {
        &self.token.community_id
    }

    /// Loads the esm.key file from the disk and converts it to a Token
    pub fn load(&mut self) -> ESMResult {
        let path = match std::env::current_dir() {
            Ok(mut p) => {
                p.push("@esm");
                p.push("esm.key");
                p
            }
            Err(e) => return Err(format!("Failed to get current directory. Reason: {e}").into()),
        };

        let mut file = match File::open(&path) {
            Ok(file) => file,
            Err(_) => return Err(format!("Failed to find \"esm.key\" file here: {path:?}. If you haven't registered your server yet, please visit https://esmbot.com/wiki, click \"I am a Server Owner\", and follow the steps.").into())
        };

        let mut key_contents = Vec::new();
        match file.read_to_end(&mut key_contents) {
                Ok(_) => {
                    trace!(
                        "[load] esm.key - {}",
                        String::from_utf8_lossy(&key_contents)
                    );
                }
                Err(e) => return Err(format!("Failed to read \"esm.key\" file. Please check the file permissions and try again.\nReason: {}", e).into())
            }

        match serde_json::from_slice(&key_contents) {
            Ok(token) => {
                self.token.update_from(token);
                trace!("[load] Token loaded - {}", self.token);
                Ok(())
            }
            Err(e) => {
                Err(format!("Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).\nError: {e}").into())
            }
        }
    }

    pub fn reload(&mut self) -> &mut Self {
        let reload_file = std::path::Path::new("@esm\\.RELOAD");
        if !reload_file.exists() {
            return self;
        }

        if let Err(e) = self.load() {
            error!("[reload] ❌ {}", e);
            return self;
        };

        match std::fs::remove_file(reload_file) {
            Ok(_) => {}
            Err(e) => error!("[reload] ❌ {}", e),
        }

        warn!("[reload] ⚠ Token was reloaded");
        self
    }
}
