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

    pub fn send(&self, message: Message) -> ESMResult {
        if !matches!(message.message_type, Type::Init) {
            debug!("[bot#send] {}", message);
        }
        crate::connection_manager::CLIENT.send(message)
    }

    pub async fn on_connect(&self) -> ESMResult {
        self.connection_manager
            .connected
            .store(true, Ordering::SeqCst);

        // The NetEvent::Connected must complete before we attempt to send any messages to the bot
        // The event completes once bot#on_connect exits
        tokio::spawn(async {
            while !crate::connection_manager::CLIENT.ready() {
                tokio::time::sleep(tokio::time::Duration::from_millis(1)).await;
            }

            let mut message = Message::new(Type::Init);
            message.data = Data::Init(lock!(crate::ARMA).init.clone());

            debug!("[bot#on_connect] Initialization {:#?}", message);

            if let Err(e) = crate::BOT.send(message) {
                error!("[bot#on_connect] {}", e);
            }
        });

        Ok(())
    }

    pub fn on_message(&self, message: Message) -> ESMResult {
        if !message.errors.is_empty() {
            for error in message.errors {
                error!("[bot#on_message] {}", error.error_content);
            }

            return Ok(());
        }

        info!(
            "[bot#on_message] Received {:?} message with ID {}",
            message.message_type, message.id
        );

        let result: Option<Message> = match message.message_type {
            Type::Init => lock!(crate::ARMA).post_initialization(message)?,
            Type::Query => Some(lock!(crate::ARMA).database.query(message)),
            Type::Arma => lock!(crate::ARMA).call_function(message)?,
            Type::Test => Some(message),
            _ => {
                return Err(format!(
                    "Message type \"{:?}\" has not been implemented yet",
                    message.message_type
                )
                .into())
            }
        };

        // If a message is returned, send it back
        if let Some(m) = result {
            self.send(m)?;
        }

        Ok(())
    }

    pub async fn on_disconnect(&self) -> ESMResult {
        self.connection_manager
            .connected
            .store(false, Ordering::SeqCst);

        crate::READY.store(false, Ordering::SeqCst);
        Ok(())
    }
}
