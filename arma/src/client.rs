
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

#[derive(Clone)]
pub struct Client {
    token: Arc<Token>,
    initialization_data: Arc<RwLock<Data>>,
    handler: Arc<RwLock<NodeHandler<()>>>,
    listener: Arc<RwLock<Option<NodeListener<()>>>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
    reconnection_counter: Arc<AtomicI16>,
    bot_pong_received: Arc<AtomicBool>
}

impl Client {
    pub fn new(token: Token, initialization_data: Data) -> Self {
        let (handler, listener) = node::split::<()>();

        Client {
            token: Arc::new(token),
            initialization_data: Arc::new(RwLock::new(initialization_data)),
            handler: Arc::new(RwLock::new(handler)),
            listener: Arc::new(RwLock::new(Some(listener))),
            endpoint: Arc::new(RwLock::new(None)),
            reconnection_counter: Arc::new(AtomicI16::new(1)),
            bot_pong_received: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn token(&self) -> &Token {
        &self.token
    }

    pub fn connect(&self) {
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
            listener.for_each(move |event| match event.network() {
                NetEvent::Connected(_, connected) => {
                    if !connected {
                        client.reconnect();
                        return
                    };

                    client.on_connect();
                }
                NetEvent::Accepted(_, _) => unreachable!(),
                NetEvent::Message(_, incoming_data) => {
                    client.on_message(incoming_data.into());
                }
                NetEvent::Disconnected(_) => {
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

        // Get the current reconnection count and calculate the wait time
        let current_count = self.reconnection_counter.load(Ordering::SeqCst);
        let time_to_wait = if crate::CONFIG.env.development() {
            3
        } else {
            15 * (current_count as u64)
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

        // Add the server ID if there is none
        if message.server_id.is_none() {
            message.server_id = Some(self.token.id.clone());
        }

        // Convert the message to bytes so it can be sent
        match message.as_bytes(|_| Some(self.token.key.clone())) {
            Ok(bytes) => {
                debug!("[client#send_to_server] {:#?}", message);

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
                    error!("[client#connect] Failed to socket addr");
                    return;
                }
            },
            Err(e) => {
                error!("[client#connect] Failed to convert. Reason: {}", e);
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

    fn on_connect(&self) {
        info!("[client#on_connect] Connected to server");

        // Reset the reconnect counter.
        self.reconnection_counter.store(0, Ordering::SeqCst);

        let mut message = Message::new(Type::Init);
        message.data = self.initialization_data.read().clone();

        // debug!("[client#on_connect] Initialization {:#?}", message);

        self.send_to_server(message);
    }

    fn on_message(&self, incoming_data: Vec<u8>) {
        let endpoint = match self.endpoint() {
            Some(e) => e,
            None => return
        };

        let message = Message::from_bytes(incoming_data, |_| Some(self.token.key.clone()));

        let message = match message {
            Ok(mut message) => {
                message.set_resource(endpoint.resource_id());
                message
            },
            Err(e) => {
                error!("[client#on_message] {}", e);
                return;
            }
        };

        info!("[client#on_message] Received {:?} message with ID {}", message.message_type, message.id);
        // debug!("[client#on_message] {:#?}", message);

        let arma = crate::ARMA.read();
        let result: Option<Message> = match message.message_type {
            Type::Init => {
                drop(arma); // Release the read so a write can be established

                let mut writer_arma = crate::ARMA.write();
                writer_arma.post_initialization(message)
            },
            Type::Query => arma.database.query(message),
            Type::Arma => arma.call_function(message),
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
