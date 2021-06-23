use std::collections::HashMap;
use std::net::ToSocketAddrs;
use std::sync::Arc;
use std::thread;

use esm_message::{Data, Message, Type};
use log::*;
use message_io::network::{Endpoint, NetEvent, RemoteAddr, ToRemoteAddr, Transport};
use message_io::node::{self, NodeEvent, NodeHandler, NodeListener, NodeTask};
use parking_lot::RwLock;
use serde_json::Value;

use crate::arma::data::Token;

#[derive(Clone)]
pub struct Client {
    token: Arc<Token>,
    initialization_data: Arc<RwLock<Data>>,
    handler: Arc<RwLock<NodeHandler<()>>>,
    listener: Arc<RwLock<Option<NodeListener<()>>>>,
    endpoint: Arc<RwLock<Option<Endpoint>>>,
}

impl Client {
    pub fn new(token: Token, initialization_data: Data) -> Self {
        let (handler, listener) = node::split::<()>();
        let token = Arc::new(token);
        let initialization_data = Arc::new(RwLock::new(initialization_data));
        let handler = Arc::new(RwLock::new(handler));
        let listener = Arc::new(RwLock::new(Some(listener)));
        let endpoint = Arc::new(RwLock::new(None));

        Client {
            token,
            initialization_data,
            handler,
            listener,
            endpoint,
        }
    }

    pub fn connect(&self) {
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
            Ok((endpoint, _)) => {
                debug!("[Client#connect] Connected to server - Joining lobby");
                endpoint
            }
            Err(_) => {
                // Attempt reconnect
                trace!("[Client#connect] Failed to connect");
                return;
            }
        };

        *self.endpoint.write() = Some(endpoint);

        let client = self.clone();
        let listener = match self.listener.write().take() {
            Some(listener) => listener,
            None => {
                error!("[Client#connect] (BUG) Failed to take NodeListener");
                return;
            }
        };

        thread::spawn(|| {
            listener.for_each(move |event| match event.network() {
                NetEvent::Connected(_, connected) => {
                    if !connected {
                        return;
                    };

                    let mut message = Message::new(Type::Connect);
                    message.set_data(client.initialization_data.read().clone());

                    client.send_to_bot(message);
                }
                NetEvent::Accepted(_, _) => unreachable!(),
                NetEvent::Message(_, data) => {
                    debug!("[Client#connect] Data: {:?}", data);
                }
                NetEvent::Disconnected(_) => {
                    // Attempt Reconnect
                    trace!("[Client#connect] Disconnected");
                }
            });
        });
    }

    pub fn send_to_bot(&self, mut message: Message) {
        if let None = message.server_id {
            message.server_id = Some(self.token.id.clone());
        }

        let endpoint = match *self.endpoint.read() {
            Some(e) => e,
            None => {
                error!("[Client#send_to_bot] (BUG) Failed to find the server endpoint. Was #connect not called?");
                return;
            }
        };

        match message.as_bytes(|_| Some(self.token.key.clone())) {
            Ok(bytes) => {
                trace!(
                    "[Client#send_to_bot] id: {:?}, message: {:?}, message: {:?}",
                    self.token.id,
                    message,
                    &bytes
                );
                self.handler
                    .read()
                    .network()
                    .send(endpoint.to_owned(), &bytes);
            }
            Err(error) => {
                error!("{}", error);
            }
        }
    }
}
