use esm_message::Message;

use crate::{client::Client, token::Token};

pub struct Bot {
    client: Client,
}

impl Bot {
    pub fn new() -> Self {
        Bot {
            client: Client::new(),
        }
    }

    pub fn token(&self) -> &Token {
        &self.client.token
    }

    pub fn send(&mut self, message: Message) {
        self.client.send(message);
    }

    fn connect(&mut self) {
        self.client.connect();
    }
}
