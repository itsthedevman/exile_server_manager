use crate::token::Token;
use crate::*;

use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeTask};
use std::fs::File;
use std::io::Read;
use std::net::ToSocketAddrs;

lazy_static! {
    pub static ref TOKEN_MANAGER: RwLock<TokenManager> = RwLock::new(TokenManager::new());
    pub static ref HANDLER: RwLock<Option<NodeHandler<()>>> = RwLock::new(None);
    pub static ref TASK: RwLock<Option<NodeTask>> = RwLock::new(None);
    pub static ref ENDPOINT: RwLock<Option<Endpoint>> = RwLock::new(None);
}

#[derive(Default)]
pub struct Client {}

impl Client {
    pub fn new() -> Self {
        Client::default()
    }

    pub async fn connect(&self) -> Result<(), String> {
        if let Err(e) = write_lock!(TOKEN_MANAGER).load() {
            error!("[client#connect] {}", e);
        };

        debug!("[client#connect] Attempting to connect to esm_bot");

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
            Ok((endpoint, _)) => *write_lock!(ENDPOINT) = Some(endpoint),
            Err(e) => return Err(format!("{e}")),
        };

        *write_lock!(HANDLER) = Some(handler);
        let task = listener.for_each_async(|event| match event.network() {
            NetEvent::Connected(_, connected) => {
                TOKIO_RUNTIME.block_on(async {
                    debug!("[client#on_connect] Are we connected? {}", connected);

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
                    trace!("[client#on_message] Incoming data: {:?}", String::from_utf8_lossy(&incoming_data));

                    write_lock!(TOKEN_MANAGER).reload();
                    let token = read_lock!(TOKEN_MANAGER);
                    if !token.valid() {
                        error!("[client#on_message] Cannot process inbound message - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
                        return;
                    }

                    let message =
                        match Message::from_bytes(incoming_data, token.key_bytes()) {
                            Ok(message) => {
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

                    if let Err(e) = crate::BOT.on_message(message).await {
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
                    debug!("[client#on_disconnect] Lost connection");

                    if let Err(e) = crate::BOT.on_disconnect().await {
                        error!("[client#on_disconnect] {}", e);
                    };
                });
            }
        });

        *write_lock!(TASK) = Some(task);

        Ok(())
    }

    pub fn ready(&self) -> bool {
        let endpoint = match *read_lock!(ENDPOINT) {
            Some(e) => e,
            None => return false,
        };

        let handler = match *read_lock!(HANDLER) {
            Some(ref h) => h.clone(),
            None => return false,
        };

        !matches!(
            handler.network().is_ready(endpoint.resource_id()),
            Some(false) | None
        )
    }

    pub async fn send(&self, mut message: Message) -> ESMResult {
        debug!("[send] 1");
        if !self.ready() {
            return Err(
                "[client#send] Cannot send - We are not connected to the bot at the moment".into(),
            );
        }

        debug!("[send] 2");
        write_lock!(TOKEN_MANAGER).reload();
        debug!("[send] 3");
        let token = read_lock!(TOKEN_MANAGER);
        if !token.valid() {
            return Err("[client#send] Cannot send - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
        }
        debug!("[send] 4");
        // Add the server ID if there is none
        if message.server_id.is_none() {
            message.server_id = Some(token.id_bytes().to_vec());
        }

        // Convert the message to bytes so it can be sent
        match message.as_bytes(token.key_bytes()) {
            Ok(bytes) => {
                debug!("[send] 5");
                if !matches!(message.message_type, Type::Init) {
                    debug!("[client#send] {}", message);
                }

                let handler = match *read_lock!(HANDLER) {
                    Some(ref h) => h.clone(),
                    None => {
                        return Err(
                            "[client#send] No handler found - Did you not call #connect?".into(),
                        )
                    }
                };

                let endpoint = match *read_lock!(ENDPOINT) {
                    Some(e) => e,
                    None => {
                        return Err(
                            "[client#send] No endpoint found - Did you not call #connect?".into(),
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
}

#[derive(Default)]
pub struct TokenManager {
    token: Token,
}

impl TokenManager {
    pub fn new() -> Self {
        TokenManager::default()
    }

    pub fn valid(&self) -> bool {
        self.token.valid()
    }

    pub fn id_bytes(&self) -> &[u8] {
        &self.token.id
    }

    pub fn key_bytes(&self) -> &[u8] {
        &self.token.key
    }

    pub fn server_id(&self) -> &str {
        &self.token.server_id
    }

    pub fn community_id(&self) -> &str {
        &self.token.community_id
    }

    /// Loads the esm.key file from the disk and converts it to a Token
    pub fn load(&mut self) -> ESMResult {
        let path = match std::env::current_dir() {
            Ok(mut p) => {
                p.push("@esm");
                p.push("esm.key");
                p
            }
            Err(e) => return Err(format!("Failed to get current directory. Reason: {e}").into()),
        };

        let mut file = match File::open(&path) {
            Ok(file) => file,
            Err(_) => return Err(format!("Failed to find \"esm.key\" file here: {path:?}. If you haven't registered your server yet, please visit https://esmbot.com/wiki, click \"I am a Server Owner\", and follow the steps.").into())
        };

        let mut key_contents = Vec::new();
        match file.read_to_end(&mut key_contents) {
                Ok(_) => {
                    trace!(
                        "[token_manager::load] esm.key - {}",
                        String::from_utf8_lossy(&key_contents)
                    );
                }
                Err(e) => return Err(format!("Failed to read \"esm.key\" file. Please check the file permissions and try again.\nReason: {}", e).into())
            }

        match serde_json::from_slice(&key_contents) {
            Ok(token) => {
                self.token.update_from(token);
                trace!("[token_manager::load] Token loaded - {}", self.token);
                Ok(())
            }
            Err(e) => {
                Err(format!("Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).\nError: {e}").into())
            }
        }
    }

    pub fn reload(&mut self) {
        let reload_file = std::path::Path::new("@esm\\.RELOAD");
        if !reload_file.exists() {
            return;
        }

        if let Err(e) = self.load() {
            error!("[token_manager::reload] {}", e);
            return;
        };

        match std::fs::remove_file(reload_file) {
            Ok(_) => {}
            Err(e) => error!("[token_manager#reload] {}", e),
        }

        warn!("[token_manager#reload] Token was reloaded");
    }
}
