
use std::net::ToSocketAddrs;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicI16, Ordering};
use std::thread::{self};
use std::time::Duration;

use esm_message::{Data, Message, Type};
use log::*;
use message_io::network::{Endpoint, NetEvent, Transport};
use message_io::node::{self, NodeHandler, NodeListener};
use parking_lot::RwLock;

use crate::arma::data::Token;
use crate::config::Env;

#[derive(Clone)]
pub struct Client {
    pub token: Arc<RwLock<Token>>,
    initialization_data: Arc<RwLock<Data>>,
    handler: Arc<RwLock<NodeHandler<()>>>,
    listener: Arc<RwLock<Option<NodeListener<()>>>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
    reconnection_counter: Arc<AtomicI16>,
    bot_pong_received: Arc<AtomicBool>,
    connected: Arc<AtomicBool>,
}

impl Client {
    pub fn new(token: Token, initialization_data: Data) -> Self {
        let (handler, listener) = node::split::<()>();

        Client {
            token: Arc::new(RwLock::new(token)),
            initialization_data: Arc::new(RwLock::new(initialization_data)),
            handler: Arc::new(RwLock::new(handler)),
            listener: Arc::new(RwLock::new(Some(listener))),
            endpoint: Arc::new(RwLock::new(None)),
            reconnection_counter: Arc::new(AtomicI16::new(1)),
            bot_pong_received: Arc::new(AtomicBool::new(false)),
            connected: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn connect(&self) {
        trace!("[client#connect] Connecting to esm");

        self.load_endpoint();

        let listener = match self.listener.write().take() {
            Some(listener) => listener,
            None => {
                error!("[client#connect] (BUG) Failed to take NodeListener");
                return;
            }
        };

        let client = self.clone();
        thread::spawn(|| {
            trace!("[client#connect] Listening for events");

            listener.for_each(move |event| match event.network() {
                NetEvent::Connected(_, connected) => {
                    trace!("[client#connect] Event Connected: {}", connected);

                    if !connected {
                        client.reconnect();
                        return
                    };

                    client.on_connect();
                }
                NetEvent::Accepted(_, _) => unreachable!(),
                NetEvent::Message(_, incoming_data) => {
                    trace!("[client#connect] Event Message: {:?}", incoming_data);

                    client.on_message(incoming_data.into());
                }
                NetEvent::Disconnected(_) => {
                    trace!("[client#connect] Event Disconnected");

                    client.on_disconnect();
                }
            });
        });
    }

    /// Attempts to reconnect to the bot with no max attempts.
    /// Each time it attempts to reconnect, it will wait +15sec longer than the last attempt; waiting no longer than 5 minutes between attempts
    /// When env is set to "development", it will attempt roughly every second.
    pub fn reconnect(&self) {
        self.handler.read().stop();
        self.connected.store(false, Ordering::SeqCst);

        // Get the current reconnection count and calculate the wait time
        let current_count = self.reconnection_counter.load(Ordering::SeqCst);
        let time_to_wait = match crate::CONFIG.env {
            Env::Test => 1,
            Env::Development => 3,
            _ => 15 * (current_count as u64)
        };

        let time_to_wait = Duration::from_secs(time_to_wait);
        warn!("[client#reconnect] Lost connection to server - Attempting reconnect in {:?}", time_to_wait);

        thread::sleep(time_to_wait);

        // Sleep a max of 5 minutes
        if current_count <= 20 {
            // Increase the reconnect counter by 1
            self.reconnection_counter.store(current_count + 1, Ordering::SeqCst);
        }

        let (handler, listener) = node::split::<()>();
        *self.handler.write() = handler;
        *self.listener.write() = Some(listener);

        self.connect();
    }

    pub fn send_to_server(&self, mut message: Message) {
        let endpoint = match self.endpoint() {
            Some(e) => e,
            None => return
        };

        let handler = self.handler.read();
        let network = handler.network();

        match network.is_ready(endpoint.resource_id()) {
            Some(false) | None => {
                error!("[client#send_to_server] Failed to send, server not connected");
                return;
            },
            _ => {}
        }

        // Only reloads if the env is set to test
        self.reload_token();

        // Add the server ID if there is none
        let token = self.token.read();

        if message.server_id.is_none() {
            message.server_id = Some(token.id.clone());
        }

        // Convert the message to bytes so it can be sent
        match message.as_bytes(&token.key) {
            Ok(bytes) => {
                if message.message_type != Type::Init {
                    debug!("[client#send_to_server] {:?}", message);
                }

                network.send(endpoint, &bytes);
            }
            Err(error) => {
                error!("{}", error);
            }
        }
    }

    fn load_endpoint(&self) {
        let server_address = match crate::CONFIG.connection_url.to_socket_addrs() {
            Ok(mut addr) => match addr.next() {
                Some(socket_addr) => socket_addr,
                None => {
                    error!("[client#connect] Failed to convert connection_url to socket addr");
                    return;
                }
            },
            Err(e) => {
                error!("[client#connect] Failed to parse connection url from {:?}. Reason: {}", crate::CONFIG.connection_url, e);
                return;
            }
        };

        let endpoint = match self
            .handler
            .read()
            .network()
            .connect(Transport::FramedTcp, server_address)
        {
            Ok((endpoint, _)) => endpoint,
            Err(_) => {
                // Attempt reconnect
                error!("[client#connect] Failed to connect");
                return;
            }
        };

        *self.endpoint.write() = Some(endpoint);
    }

    fn endpoint(&self) -> Option<Endpoint> {
        let endpoint = *self.endpoint.read();

        if endpoint.is_none() {
            error!("[client#endpoint] ");
            return None;
        }

        endpoint
    }

    fn reload_token(&self) {
        let reload_file = std::path::Path::new("@esm\\.RELOAD");
        if !(crate::CONFIG.env.test() && reload_file.exists()) { return }

        let new_token = match crate::load_key() {
            Some(t) => t,
            None => {
                error!("[client#reload_token] Failed to reload key");
                return
            }
        };

        trace!("[client#reload_token] Reloaded token");

        *self.token.write() = new_token;

        match std::fs::remove_file(reload_file) {
            Ok(_) => {},
            Err(e) => error!("[client#reload_token] {}", e)
        }
    }

    fn on_connect(&self) {
        // Reset the reconnect counter.
        self.reconnection_counter.store(0, Ordering::SeqCst);

        let mut message = Message::new(Type::Init);
        message.data = self.initialization_data.read().clone();

        trace!("[client#on_connect] Initialization {:#?}", message);

        self.send_to_server(message);
    }

    fn on_message(&self, incoming_data: Vec<u8>) {
        let endpoint = match self.endpoint() {
            Some(e) => e,
            None => return
        };

        // Only reloads if the env is set to test
        self.reload_token();

        let message = match Message::from_bytes(incoming_data, &self.token.read().key) {
            Ok(mut message) => {
                message.set_resource(endpoint.resource_id());
                message
            },
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

        info!("[client#on_message] Received {:?} message with ID {}", message.message_type, message.id);

        let arma = crate::ARMA.read();
        let result: Option<Message> = match message.message_type {
            Type::Init => {
                if self.connected.load(Ordering::SeqCst) {
                    error!("[client#on_message] Client is already initialized");
                    return
                }

                info!("[client#on_message] Connection established with bot");
                self.connected.store(true, Ordering::SeqCst);

                drop(arma); // Release the read so a write can be established
                let mut arma = crate::ARMA.write();
                arma.post_initialization(message)
            },
            Type::Query => arma.database.query(message),
            Type::Arma => arma.call_function(message),
            Type::Test => {
                // Only allow this message type when explicitly in test env
                match crate::CONFIG.env {
                    crate::config::Env::Test => {
                        // All this does is just reloads the key.
                        let token = crate::load_key().unwrap();
                        *self.token.write() = token;
                        info!("[#on_message] Token reloaded");
                        None
                    },
                    _ => None,
                }
            }
            _ => unreachable!("[client::on_message] This is a bug. Message type \"{:?}\" has not been implemented yet", message.message_type),
        };

        // If a message is returned, send it back
        if let Some(m) = result {
            self.send_to_server(m);
        }
    }

    fn on_disconnect(&self) {
        self.reconnect();
    }
}
