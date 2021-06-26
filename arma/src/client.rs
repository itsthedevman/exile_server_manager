
use std::net::ToSocketAddrs;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicI16, Ordering};
use std::thread::{self, sleep};
use std::time::Duration;

use esm_message::{Data, Message, Type};
use log::*;
use message_io::network::{Endpoint, NetEvent, Transport};
use message_io::node::{self, NodeHandler, NodeListener};
use parking_lot::RwLock;


use crate::arma::data::Token;

const MAX_RECONNECT: i16 = 15;

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
            reconnection_counter: Arc::new(AtomicI16::new(0)),
            bot_pong_received: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn connect(&self) {
        self.load_endpoint();

        let listener = match self.listener.write().take() {
            Some(listener) => listener,
            None => {
                error!("[Client#connect] (BUG) Failed to take NodeListener");
                return;
            }
        };

        let client = self.clone();
        thread::spawn(|| {
            listener.for_each(move |event| match event.network() {
                NetEvent::Connected(_, connected) => {
                    if !connected { return };

                    client.on_connect();
                }
                NetEvent::Accepted(_, _) => unreachable!(),
                NetEvent::Message(_, incoming_data) => {
                    client.on_message(incoming_data.into());
                }
                NetEvent::Disconnected(_) => {
                    client.reconnect();
                }
            });

            warn!("DONE");
        });
    }

    pub fn reconnect(&self) {
        self.handler.read().stop();

        // Get the current reconnection count and check
        let current_count = self.reconnection_counter.load(Ordering::SeqCst);
        if current_count >= MAX_RECONNECT {
            warn!("[Client#reconnect] Lost connection to server - No more reconnect attempts will be made this restart");
            return;
        }

        warn!("[Client#reconnect] Lost connection to server - Attempting reconnect {} of {}", current_count + 1, MAX_RECONNECT);

        thread::sleep(Duration::from_secs(1));

        // Increase the reconnect counter by 1
        self.reconnection_counter.store(current_count + 1, Ordering::SeqCst);

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
                error!("[Client#send_to_server] Failed to send, server not connected");
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
                trace!(
                    "[Client#send_to_server] id: {:?}, message: {:?}, message: {:?}",
                    self.token.id,
                    message,
                    &bytes
                );

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
                    error!("[Client#connect] Failed to socket addr");
                    return;
                }
            },
            Err(e) => {
                error!("[Client#connect] Failed to convert. Reason: {}", e);
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
                error!("[Client#connect] Failed to connect");
                return;
            }
        };

        *self.endpoint.write() = Some(endpoint);
    }

    fn endpoint(&self) -> Option<Endpoint> {
        let endpoint = *self.endpoint.read();

        if endpoint.is_none() {
            error!("[Client#endpoint] ");
            return None;
        }

        endpoint
    }

    fn on_connect(&self) {
        debug!("[Client#connect] Connected to server - Sending connection message");

        // Reset the reconnect counter.
        self.reconnection_counter.store(0, Ordering::SeqCst);

        let mut message = Message::new(Type::Connect);
        message.set_data(self.initialization_data.read().clone());

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
                error!("#on_message - {}", e);
                return;
            }
        };

        info!("#on_message - {:#?}", message);

        match message.message_type {
            _ => {}
        };
    }
}
