use esm_message::{Data, Message, Type};
use log::*;

use crate::{client::Client, error::ESMResult, token::Token};

pub struct Bot {
    pub client: Client,
}

impl Default for Bot {
    fn default() -> Self {
        Bot {
            client: Client::new(),
        }
    }
}

impl Bot {
    pub fn new() -> Self {
        Bot::default()
    }

    pub fn token(&self) -> &Token {
        &self.client.token
    }

    pub fn send(&mut self, message: Message) -> ESMResult {
        self.client.send(message)
    }

    pub fn connect(&mut self) -> ESMResult {
        self.client.connect()?;
        Ok(())
    }

    pub fn on_connect(&mut self) -> ESMResult {
        let mut message = Message::new(Type::Init);
        message.data = Data::Init(crate::ARMA.read().init.clone());

        trace!("[client#on_connect] Initialization {:#?}", message);

        self.send(message)
    }

    pub fn on_message(&mut self, message: Message) -> ESMResult {
        trace!("[client#on_message] {:#?}", message);

        if !message.errors.is_empty() {
            for error in message.errors {
                error!("{}", error.error_content);
            }

            return Ok(());
        }

        info!(
            "[client#on_message] Received {:?} message with ID {}",
            message.message_type, message.id
        );

        let arma = crate::ARMA.read();
        let result: Option<Message> = match message.message_type {
            Type::Init => {
                drop(arma); // Release the read so a write can be established
                let mut arma = crate::ARMA.write();
                arma.post_initialization(message)?
            },
            Type::Query => Some(arma.database.query(message)),
            Type::Arma => arma.call_function(message)?,
            _ => unreachable!("[client::on_message] This is a bug. Message type \"{:?}\" has not been implemented yet", message.message_type),
        };

        // If a message is returned, send it back
        if let Some(m) = result {
            self.send(m)?;
        }

        Ok(())
    }

    pub fn on_disconnect(&self) -> ESMResult {
        error!("[bot#on_disconnect] Lost connection to the bot");
        Ok(())
    }
}
