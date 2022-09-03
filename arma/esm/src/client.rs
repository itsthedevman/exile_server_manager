use crate::token::TokenManager;
use crate::*;

use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeTask};
use std::net::ToSocketAddrs;

lazy_static! {
    pub static ref TOKEN_MANAGER: Arc<Mutex<TokenManager>> =
        Arc::new(Mutex::new(TokenManager::new()));
    pub static ref HANDLER: Arc<Mutex<Option<NodeHandler<()>>>> = Arc::new(Mutex::new(None));
    pub static ref TASK: Arc<Mutex<Option<NodeTask>>> = Arc::new(Mutex::new(None));
    pub static ref ENDPOINT: Arc<Mutex<Option<Endpoint>>> = Arc::new(Mutex::new(None));
}

#[derive(Default)]
pub struct Client {}

impl Client {
    pub fn new() -> Self {
        Client::default()
    }

    pub fn connect(&self) -> Result<(), String> {
        if let Err(e) = lock!(TOKEN_MANAGER).load() {
            error!("[client#connect] {}", e);
        };

        if !matches!(crate::CONFIG.env, Env::Test) {
            debug!("[client#connect] Attempting to connect to esm_bot");
        }

        // This is validated on extension#pre_init
        let server_address = crate::CONFIG
            .connection_url
            .to_socket_addrs()
            .unwrap()
            .next()
            .unwrap();

        let (handler, listener) = node::split::<()>();

        match handler
            .network()
            .connect(Transport::FramedTcp, server_address)
        {
            Ok((endpoint, _)) => *lock!(ENDPOINT) = Some(endpoint),
            Err(e) => return Err(format!("{e}")),
        };

        *lock!(HANDLER) = Some(handler);
        let task = listener.for_each_async(|event| match event.network() {
            NetEvent::Connected(_, connected) => {
                TOKIO_RUNTIME.block_on(async {
                    if !matches!(crate::CONFIG.env, Env::Test) {
                        debug!("[client#on_connect] Are we connected? {}", connected);
                    }

                    if !connected {
                        if let Err(e) = crate::BOT.on_disconnect().await {
                            error!("[client#on_connect] {}", e)
                        };

                        return;
                    };

                    if let Err(e) = crate::BOT.on_connect().await {
                        error!("[client#on_connect] {}", e)
                    };
                });
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_, incoming_data) => {
                let incoming_data = incoming_data.to_vec();
                TOKIO_RUNTIME.block_on(async {
                    debug!("[client#on_message] Incoming data: {:?}", String::from_utf8_lossy(&incoming_data));

                    let mut token = lock!(TOKEN_MANAGER);
                    if !token.reload().valid() {
                        error!("[client#on_message] Cannot process inbound message - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
                        return;
                    }

                    let message =
                        match Message::from_bytes(incoming_data, token.key_bytes()) {
                            Ok(message) => {
                                drop(token);
                                debug!("[client#on_message] {message}");
                                message
                            },
                            Err(e) => {
                                error!("[client#on_message] {}", e);
                                return;
                            }
                        };

                    let message_type = message.message_type;
                    if matches!(message_type, Type::Init) && crate::READY.load(Ordering::SeqCst) {
                        error!("[client#on_message] Client is already initialized");
                        return;
                    }

                    if let Err(e) = crate::BOT.on_message(message) {
                        error!("[client#on_message] {}", e)
                    };

                    if matches!(message_type, Type::Init) {
                        info!("[client#on_message] Connection established with bot");
                        crate::READY.store(true, Ordering::SeqCst);
                    }
                });
            }
            NetEvent::Disconnected(_) => {
                TOKIO_RUNTIME.block_on(async {
                    if !matches!(crate::CONFIG.env, Env::Test) {
                        debug!("[client#on_disconnect] Lost connection");
                    }

                    if let Err(e) = crate::BOT.on_disconnect().await {
                        error!("[client#on_disconnect] {}", e);
                    };
                });
            }
        });

        *lock!(TASK) = Some(task);

        Ok(())
    }

    pub fn ready(&self) -> bool {
        let endpoint = match *lock!(ENDPOINT) {
            Some(e) => e,
            None => return false,
        };

        let handler = match *lock!(HANDLER) {
            Some(ref h) => h.clone(),
            None => return false,
        };

        !matches!(
            handler.network().is_ready(endpoint.resource_id()),
            Some(false) | None
        )
    }

    pub fn send(&self, mut message: Message) -> ESMResult {
        if !self.ready() {
            return Err(
                "[client#send] Cannot send - We are not connected to the bot at the moment".into(),
            );
        }

        let mut token = lock!(TOKEN_MANAGER);
        if !token.reload().valid() {
            return Err("[client#send] Cannot send - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
        }

        // Add the server ID if there is none
        if message.server_id.is_none() {
            message.server_id = Some(token.id_bytes().to_vec());
        }

        // Convert the message to bytes so it can be sent
        match message.as_bytes(token.key_bytes()) {
            Ok(bytes) => {
                drop(token);
                if !matches!(message.message_type, Type::Init) {
                    debug!("[client#send] {}", message);
                }

                debug!("Before handler");
                let handler = match *lock!(HANDLER) {
                    Some(ref h) => h.clone(),
                    None => {
                        return Err(
                            "[client#send] No handler found - Did you not call #connect?".into(),
                        )
                    }
                };

                debug!("Before endpoint");
                let endpoint = match *lock!(ENDPOINT) {
                    Some(e) => e,
                    None => {
                        return Err(
                            "[client#send] No endpoint found - Did you not call #connect?".into(),
                        )
                    }
                };

                debug!("Before send");
                match handler.network().send(endpoint, &bytes) {
                    SendStatus::Sent => {
                        debug!("After send");
                        Ok(())
                    },
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
}
