
use std::net::ToSocketAddrs;
use std::sync::Arc;
use std::sync::atomic::{AtomicI16, Ordering};
use std::thread;
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
    reconnection_counter: Arc<AtomicI16>
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
                    if !connected {
                        return;
                    };

                    debug!("[Client#connect] Connected to server - Sending connection message");

                    // Reset the reconnect counter.
                    client.reconnection_counter.store(0, Ordering::SeqCst);

                    let mut message = Message::new(Type::Connect);
                    message.set_data(client.initialization_data.read().clone());

                    client.send_to_bot(message);
                }
                NetEvent::Accepted(_, _) => unreachable!(),
                NetEvent::Message(_, _data) => {
                    // debug!("[Client#connect] Data: {:?}", data);
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

    pub fn send_to_bot(&self, mut message: Message) {
        let endpoint = match *self.endpoint.read() {
            Some(e) => e.to_owned(),
            None => {
                error!("[Client#send_to_bot] (BUG) Failed to find the server endpoint. Was #connect not called?");
                return;
            }
        };

        let handler = self.handler.read();
        let network = handler.network();

        match network.is_ready(endpoint.resource_id()) {
            Some(false) | None => {
                error!("[Client#send_to_bot] Failed to send, server not connected");
                return;
            },
            _ => {}
        }

        // Add the server ID if there is none
        if message.server_id.is_none() {
            message.server_id = Some(self.token.id.clone());
        }

        match message.as_bytes(|_| Some(self.token.key.clone())) {
            Ok(bytes) => {
                trace!(
                    "[Client#send_to_bot] id: {:?}, message: {:?}, message: {:?}",
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
}
