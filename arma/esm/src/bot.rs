use crate::*;

pub struct Bot {
    connection_manager: ConnectionManager,
}

impl Default for Bot {
    fn default() -> Self {
        Bot {
            connection_manager: ConnectionManager::new(),
        }
    }
}

impl Bot {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn connect(&self) {
        self.connection_manager.connect().await;
    }

    pub async fn send(&self, message: Message) -> ESMResult {
        write_lock!(crate::CLIENT).send(message).await
    }

    pub async fn on_connect(&self) -> ESMResult {
        let mut message = Message::new(Type::Init);
        message.data = Data::Init(read_lock!(crate::ARMA).init.clone());

        trace!("[bot#on_connect] Initialization {:#?}", message);

        self.send(message).await
    }

    pub async fn on_message(&self, message: Message) -> ESMResult {
        debug!("[bot#on_message] {:#?}", message);

        if !message.errors.is_empty() {
            for error in message.errors {
                error!("{}", error.error_content);
            }

            return Ok(());
        }

        info!(
            "[bot#on_message] Received {:?} message with ID {}",
            message.message_type, message.id
        );

        let result: Option<Message> = match message.message_type {
            Type::Init => write_lock!(crate::ARMA).post_initialization(message).await?,
            Type::Query => Some(read_lock!(crate::ARMA).database.query(message)),
            Type::Arma => read_lock!(crate::ARMA).call_function(message)?,
            _ => unreachable!("[bot::on_message] This is a bug. Message type \"{:?}\" has not been implemented yet", message.message_type),
        };

        // If a message is returned, send it back
        if let Some(m) = result {
            self.send(m).await?;
        }

        Ok(())
    }

    pub async fn on_disconnect(&self) -> ESMResult {
        Ok(())
    }
}
