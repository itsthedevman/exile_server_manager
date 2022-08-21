use crate::error::ESMResult;
use crate::token::Token;

use esm_message::{Message, Type};
use log::*;
use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeTask};
use std::fs::File;
use std::io::Read;
use std::net::ToSocketAddrs;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

#[derive(Clone)]
pub struct Client {
    /// Tracks if the client is connected to the server based on events
    pub connected: Arc<AtomicBool>,
    pub token: Token,
    handler: Option<NodeHandler<()>>,
    task: Arc<Option<NodeTask>>,
    endpoint: Option<Endpoint>,
}

impl Client {
    pub fn new() -> Self {
        let mut client = Client {
            handler: None,
            task: Arc::new(None),
            endpoint: None,
            token: Token::default(),
            connected: Arc::new(AtomicBool::new(false)),
        };

        if let Err(e) = client.load_token() {
            error!("[client::load_token] {}", e);
        };

        client
    }

    pub fn connect(&mut self) -> Result<(), String> {
        debug!("[client#connect] Connecting to esm_bot");

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

        let (handler, listener) = node::split::<()>();

        match handler
            .network()
            .connect(Transport::FramedTcp, server_address)
        {
            Ok((endpoint, _)) => self.endpoint = Some(endpoint),
            Err(e) => return Err(format!("{e}")),
        };

        self.handler = Some(handler);

        debug!("[client#connect] Listening for events");
        let mut client = self.clone();
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(_, connected) => client.on_connect(connected),
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_, incoming_data) => client.on_message(incoming_data),
            NetEvent::Disconnected(_) => client.on_disconnect(),
        });

        self.task = Arc::new(Some(task));

        Ok(())
    }

    pub fn ready(&self) -> bool {
        if !self.connected.load(Ordering::SeqCst) {
            return false;
        }

        let endpoint = match self.endpoint {
            Some(e) => e,
            None => return false,
        };

        let handler = match &self.handler {
            Some(h) => h,
            None => return false,
        };

        !matches!(
            handler.network().is_ready(endpoint.resource_id()),
            Some(false) | None
        )
    }

    pub fn send(&mut self, mut message: Message) -> ESMResult {
        if !self.ready() {
            return Err(
                "[client#send] Cannot send - We are not connected to the bot at the moment".into(),
            );
        }

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

                let handler = match &self.handler {
                    Some(h) => h,
                    None => {
                        return Err(
                            "[client#send] No handler found - Did you not call #connect?".into(),
                        )
                    }
                };

                match handler.network().send(endpoint, &bytes) {
                    SendStatus::Sent => Ok(()),
                    SendStatus::MaxPacketSizeExceeded => Err(format!(
                        "[client#send] Cannot send - Message is too large. Size: {}. Message: {message:?}", bytes.len()
                    )
                    .into()),
                    _ => Err("[client#send] Cannot send - We are not connected to the bot at the moment".into()),
                }
            }
            Err(error) => Err(format!("[client#send] {error}").into()),
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
                    debug!(
                        "[client::load_token] esm.key - {}",
                        String::from_utf8_lossy(&key_contents)
                    );
                }
                Err(e) => return Err(format!("Failed to read \"esm.key\" file. Please check the file permissions and try again.\nReason: {}", e))
            }

        match serde_json::from_slice(&key_contents) {
            Ok(token) => {
                debug!("[client::load_token] Token decoded - {}", token);
                self.token = token;

                Ok(())
            }
            Err(e) => {
                Err(format!("Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).\nError: {e}"))
            }
        }
    }

    fn on_connect(&mut self, connected: bool) {
        debug!("[client#on_connect] Event Connected: {}", connected);

        if !connected {
            if let Err(e) = crate::BOT.write().on_disconnect() {
                error!("[client#on_connect] {}", e)
            };

            return;
        };

        self.connected.store(true, Ordering::SeqCst);

        if let Err(e) = crate::BOT.write().on_connect() {
            error!("[client#on_connect] {}", e)
        };
    }

    fn on_message(&mut self, incoming_data: &[u8]) {
        trace!("[client#on_message] Event Message: {:?}", incoming_data);

        self.reload_token();
        if !self.validate_token() {
            error!("[client#on_message] Cannot process inbound message - Invalid token");
            return;
        }

        let endpoint = match self.endpoint {
            Some(e) => e,
            None => {
                error!("[client#on_message] No endpoint found - This is a bug!");
                return;
            }
        };

        let message = match Message::from_bytes(incoming_data.into(), &self.token.key) {
            Ok(mut message) => {
                message.set_resource(endpoint.resource_id());
                message
            }
            Err(e) => {
                error!("[client#on_message] {}", e);
                return;
            }
        };

        if matches!(message.message_type, Type::Init) {
            if crate::READY.load(Ordering::SeqCst) {
                error!("[client#on_message] Client is already initialized");
                return;
            }

            info!("[client#on_message] Connection established with bot");
            crate::READY.store(true, Ordering::SeqCst);
        }

        if let Err(e) = crate::BOT.write().on_message(message) {
            error!("[client#on_message] {}", e)
        };
    }

    fn on_disconnect(&mut self) {
        debug!("[client#connect] Event Disconnected");

        if let Err(e) = crate::BOT.write().on_disconnect() {
            error!("[client#on_disconnect] {}", e)
        };

        self.connected.store(false, Ordering::SeqCst);
    }
}
