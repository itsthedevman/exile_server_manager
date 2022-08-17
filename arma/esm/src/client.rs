use esm_message::{Data, Message, Type};
use log::*;
use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeListener, NodeTask};
use std::fs::File;
use std::io::Read;
use std::net::ToSocketAddrs;
use std::thread;
use std::time::Duration;

use crate::config::Env;
use crate::error::ESMResult;
use crate::token::Token;

pub struct Client {
    pub connected: bool,
    pub token: Token,
    handler: NodeHandler<()>,
    listener: NodeListener<()>,
    endpoint: Option<Endpoint>,
    task: Option<NodeTask>,
    reconnection_counter: usize,
}

impl Client {
    pub fn new() -> Self {
        let (handler, listener) = node::split::<()>();
        Client {
            handler,
            listener,
            connected: false,
            endpoint: None,
            task: None,
            reconnection_counter: 0,
            token: Token::default(),
        }
    }

    pub fn connect(&mut self) -> Result<(), String> {
        trace!("[client#connect] Connecting to esm");

        let server_address = match crate::CONFIG.connection_url.to_socket_addrs() {
            Ok(mut addr) => match addr.next() {
                Some(socket_addr) => socket_addr,
                None => return Err("Failed to convert connection_url to socket addr".into()),
            },
            Err(e) => {
                return Err(format!(
                    "Failed to parse connection url from {:?}. Reason: {}",
                    crate::CONFIG.connection_url,
                    e
                ))
            }
        };

        match self
            .handler
            .network()
            .connect(Transport::FramedTcp, server_address)
        {
            Ok((endpoint, _)) => self.endpoint = Some(endpoint),
            Err(e) => return Err(format!("{e}")),
        };

        trace!("[client#connect] Listening for events");

        self.listener.for_each(move |event| match event.network() {
            NetEvent::Connected(_, connected) => {
                trace!("[client#connect] Event Connected: {}", connected);

                if !connected {
                    // self.reconnect();
                    return;
                };

                self.on_connect();
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_, incoming_data) => {
                trace!("[client#connect] Event Message: {:?}", incoming_data);

                self.on_message(incoming_data.into());
            }
            NetEvent::Disconnected(_) => {
                trace!("[client#connect] Event Disconnected");

                self.on_disconnect();
            }
        });

        Ok(())
    }

    pub fn connected(&self) -> bool {
        if self.task.is_none() {
            return false;
        }

        let endpoint = match self.endpoint {
            Some(e) => e,
            None => return false,
        };

        match self.handler.network().is_ready(endpoint.resource_id()) {
            Some(false) | None => false,
            _ => true,
        }
    }

    /// Attempts to reconnect to the bot with no max attempts.
    /// Each time it attempts to reconnect, it will wait +15sec longer than the last attempt; waiting no longer than 5 minutes between attempts
    /// When env is set to "development", it will attempt roughly every second.
    pub fn reconnect(&mut self) {
        self.connected = false;

        // Get the current reconnection count and calculate the wait time
        let current_count = self.reconnection_counter;
        let time_to_wait = match crate::CONFIG.env {
            Env::Test => 1,
            Env::Development => 3,
            _ => 15 * (current_count as u64),
        };

        let time_to_wait = Duration::from_secs(time_to_wait);
        warn!(
            "[client#reconnect] Lost connection to server - Attempting reconnect in {:?}",
            time_to_wait
        );

        thread::sleep(time_to_wait);

        // Sleep a max of 5 minutes
        if current_count <= 20 {
            // Increase the reconnect counter by 1
            self.reconnection_counter += 1;
        }
    }

    pub fn send(&mut self, mut message: Message) -> ESMResult {
        self.reload_token();
        if !self.validate_token() {
            return Err("[client#send] Cannot send - Invalid token".into());
        }

        let endpoint = match self.endpoint {
            Some(e) => e,
            None => {
                return Err("[client#send] No endpoint found - Did you not call #connect?".into())
            }
        };

        // Add the server ID if there is none
        if message.server_id.is_none() {
            message.server_id = Some(self.token.id.clone());
        }

        // Convert the message to bytes so it can be sent
        match message.as_bytes(&self.token.key) {
            Ok(bytes) => {
                if !matches!(message.message_type, Type::Init) {
                    debug!("[client#send] {:?}", message);
                }

                match self.handler.network().send(endpoint, &bytes) {
                    SendStatus::Sent => Ok(()),
                    SendStatus::MaxPacketSizeExceeded => return Err(format!(
                        "[client#send] Cannot send - Message is too large. Size: {}. Message: {message:?}", bytes.len()
                    )
                    .into()),
                    _ => return Err("[client#send] Cannot send - We are not connected to the bot at the moment".into()),
                }
            }
            Err(error) => return Err(format!("[client#send] {error}").into()),
        }
    }

    fn validate_token(&self) -> bool {
        if self.token.valid() {
            return true;
        }

        error!("[client::validate_token] Corrupted \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
        false
    }

    fn reload_token(&mut self) {
        let reload_file = std::path::Path::new("@esm\\.RELOAD");
        if !reload_file.exists() {
            return;
        }

        if let Err(e) = self.load_token() {
            error!("[bot::load_token] {}", e);
            return;
        };

        match std::fs::remove_file(reload_file) {
            Ok(_) => {}
            Err(e) => error!("[bot#reload_token] {}", e),
        }

        warn!("[bot#reload_token] Token was reloaded");
    }

    /// Loads the esm.key file from the disk and converts it to a Token
    fn load_token(&mut self) -> Result<(), String> {
        let path = match std::env::current_dir() {
            Ok(mut p) => {
                p.push("@esm");
                p.push("esm.key");
                p
            }
            Err(e) => return Err(format!("Failed to get current directory. Reason: {e}")),
        };

        let mut file = match File::open(&path) {
            Ok(file) => file,
            Err(_) => return Err(format!("Failed to find \"esm.key\" file here: {path:?}. If you haven't registered your server yet, please visit https://esmbot.com/wiki, click \"I am a Server Owner\", and follow the steps."))
        };

        let mut key_contents = Vec::new();
        match file.read_to_end(&mut key_contents) {
                Ok(_) => {
                    trace!(
                        "[bot::load_token] esm.key - {}",
                        String::from_utf8_lossy(&key_contents)
                    );
                }
                Err(e) => return Err(format!("Failed to read \"esm.key\" file. Please check the file permissions and try again.\nReason: {}", e))
            }

        match serde_json::from_slice(&key_contents) {
            Ok(token) => {
                trace!("[bot::load_token] Token decoded - {}", token);
                self.token = token;

                Ok(())
            }
            Err(e) => {
                Err(format!("Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).\nError: {e}").into())
            }
        }
    }

    fn on_connect(&mut self) {
        // Reset the reconnect counter.
        self.reconnection_counter = 0;

        let mut message = Message::new(Type::Init);
        message.data = Data::Init(crate::ARMA.read().init.clone());

        trace!("[client#on_connect] Initialization {:#?}", message);

        self.send(message);
    }

    fn on_message(&mut self, incoming_data: Vec<u8>) {
        let endpoint = match self.endpoint {
            Some(e) => e,
            None => {
                error!("[client#on_message] No endpoint found - This is a bug!");
                return;
            }
        };

        self.reload_token();
        if !self.validate_token() {
            error!("[client#on_message] Cannot process inbound message - Invalid token");
            return;
        }

        let message = match Message::from_bytes(incoming_data, &self.token.key) {
            Ok(mut message) => {
                message.set_resource(endpoint.resource_id());
                message
            }
            Err(e) => {
                error!("[client#on_message] {}", e);
                return;
            }
        };

        trace!("[client#on_message] {:#?}", message);

        if !message.errors.is_empty() {
            for error in message.errors {
                error!("{}", error.error_content);
            }

            return;
        }

        info!(
            "[client#on_message] Received {:?} message with ID {}",
            message.message_type, message.id
        );

        let arma = crate::ARMA.read();
        let result: Option<Message> = match message.message_type {
            Type::Init => {
                if self.connected {
                    error!("[client#on_message] Client is already initialized");
                    return
                }

                info!("[client#on_message] Connection established with bot");
                self.connected = true;

                drop(arma); // Release the read so a write can be established
                let mut arma = crate::ARMA.write();
                arma.post_initialization(message)
            },
            Type::Query => arma.database.query(message),
            Type::Arma => arma.call_function(message),
            _ => unreachable!("[client::on_message] This is a bug. Message type \"{:?}\" has not been implemented yet", message.message_type),
        };

        // If a message is returned, send it back
        if let Some(m) = result {
            self.send(m);
        }
    }

    fn on_disconnect(&self) {
        // self.reconnect();
    }
}
