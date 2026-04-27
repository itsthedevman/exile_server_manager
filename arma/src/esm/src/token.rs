use std::{fs::File, io::Read};

use crate::{arma::DATABASE, *};
use serde::{Deserialize, Serialize};

/// Represents the esm.key file
#[derive(Serialize, Deserialize, Debug, Default, Clone)]
pub struct Token {
    pub access: String,
    pub secret: String,
}

impl Token {
    pub fn update_from(&mut self, token: Token) -> &mut Self {
        self.access = token.access;
        self.secret = token.secret;
        self
    }

    pub fn valid(&self) -> bool {
        !self.access.is_empty() && !self.secret.is_empty() && self.secret.len() >= 32
    }
}

impl std::fmt::Display for Token {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        f.debug_struct("Token")
            .field("access", &self.access)
            .field("secret", &self.secret)
            .field("valid", &self.valid())
            .finish()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_token() {
        let mut token = Token {
            access: "esm_malden".into(),
            secret: "1234567890".into(),
        };

        assert!(!token.valid());

        let new_token = Token {
            access: "add76285-8a22-4618-9897-fa0a85d50975".into(),
            secret: "Xhaum^Ft>RLEFEja`-=D~Bot`q*D_R;kjsNKkb#y?ySkflBhnKivb!M,?xml%:C*".into(),
        };

        token.update_from(new_token);

        println!("Token: {}", token);
        assert!(token.valid());
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

    pub fn access_bytes(&self) -> &[u8] {
        &self.token.access.as_bytes()
    }

    pub fn secret_bytes(&self) -> &[u8] {
        &self.token.secret.as_bytes()
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
                debug!("[load] Token loaded - {}", self.token);
                Ok(())
            }
            Err(e) => {
                Err(format!("Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).\nError: {e}").into())
            }
        }
    }

    pub fn reload(&mut self) -> &mut Self {
        let reload_file = std::path::Path::new("@esm").join(".RELOAD");
        let file_exists = reload_file.exists();

        trace!("[reload] File exists - {}", file_exists);

        if !file_exists {
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

        DATABASE.hasher.set_salt(&self.token.secret);

        info!("[reload] ✅ Token was reloaded");
        self
    }
}
