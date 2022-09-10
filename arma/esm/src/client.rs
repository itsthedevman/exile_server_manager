use crate::router::RoutingCommand;
use crate::token::TokenManager;
use crate::*;

use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeListener};
use std::net::{SocketAddr, ToSocketAddrs};
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    pub static ref TOKEN_MANAGER: Arc<Mutex<TokenManager>> =
        Arc::new(Mutex::new(TokenManager::new()));
}

pub async fn initialize(receiver: UnboundedReceiver<RoutingCommand>) {
    if let Err(e) = lock!(TOKEN_MANAGER).load() {
        error!("[client#new] ❌ {}", e);
    };

    let (handler, listener) = node::split::<()>();

    command_thread(receiver, handler).await;
    listener_thread(listener).await;
}

fn send_to_server(
    mut message: Message,
    handler: &NodeHandler<()>,
    endpoint: Endpoint,
) -> ESMResult {
    let mut token = lock!(TOKEN_MANAGER);
    if !token.reload().valid() {
        return Err("[client#send_to_server] Cannot send - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
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
                debug!("[client#send_to_server] {}", message);
            }

            match handler.network().send(endpoint, &bytes) {
                SendStatus::Sent => {
                    debug!("After send");
                    Ok(())
                },
                SendStatus::MaxPacketSizeExceeded => Err(format!(
                    "[client#send_to_server] Cannot send - Message is too large. Size: {}. Message: {message:?}", bytes.len()
                )
                .into()),
                _ => Err("[client#send_to_server] Cannot send - We are not connected to the bot at the moment".into()),
            }
        }
        Err(error) => Err(format!("[client#send_to_server] {error}").into()),
    }
}

async fn command_thread(mut receiver: UnboundedReceiver<RoutingCommand>, handler: NodeHandler<()>) {
    tokio::spawn(async move {
        let default_addr = SocketAddr::new(
            std::net::IpAddr::V4(std::net::Ipv4Addr::new(127, 0, 0, 1)),
            0,
        );

        let mut arma_init: Init = Init::default();
        let mut endpoint: Endpoint =
            Endpoint::from_listener(message_io::network::ResourceId::from(0), default_addr);

        let ready = |handler: &NodeHandler<()>, endpoint: &Endpoint| -> bool {
            endpoint.addr() != default_addr
                && matches!(
                    handler.network().is_ready(endpoint.resource_id()),
                    Some(true)
                )
        };

        // Command loop
        while let Some(command) = receiver.recv().await {
            match command {
                RoutingCommand::Connect => {
                    if let Err(errors) = arma_init.validate() {
                        error!("[client#command_thread] ❌ Attempted to connect but init data was not valid. Errors: {:?}", errors);
                        continue;
                    }

                    let server_address = crate::CONFIG
                        .connection_url
                        .to_socket_addrs()
                        .unwrap()
                        .next()
                        .unwrap();

                    if !matches!(crate::CONFIG.env, Env::Test) {
                        debug!(
                            "[client#connect] Attempting to connect to esm_bot at {server_address}"
                        );
                    }

                    match handler
                        .network()
                        .connect(Transport::FramedTcp, server_address)
                    {
                        Ok((e, _)) => endpoint = e,
                        Err(e) => {
                            error!("[client#command_thread] ❌ Failed to connect to server - {e}");
                            continue;
                        }
                    };

                    let mut message = Message::new(Type::Init);
                    message.data = Data::Init(arma_init.clone());

                    debug!("[client#command_thread] Initialization {:#?}", message);

                    // if let Err(e) = crate::BOT.send(message) {
                    //     error!("[bot#on_connect] ❌ {}", e);
                    // }
                }
                RoutingCommand::Send { message, delay } => {
                    // Make sure we are connected first
                    if ready(&handler, &endpoint) {
                        error!(
                            "[client#command_thread] Cannot send message - Not connected to bot"
                        );
                        continue;
                    }

                    // If there is a delay, just spawn it off and re-route the message back after waiting
                    if let Some(d) = delay {
                        tokio::spawn(async move {
                            tokio::time::sleep(d).await;
                            if let Err(e) = crate::ROUTER.route_to_bot(*message) {
                                error!("{e}");
                            };
                        });
                    } else if let Err(e) = send_to_server(*message, &handler, endpoint) {
                        error!("{e}");
                    }
                }
                RoutingCommand::ClientInitialize { init } => {
                    arma_init = init;

                    if let Err(e) = crate::ROUTER.route_internal("bot", RoutingCommand::Connect) {
                        error!("{e}");
                    }
                }
                c => error!(
                    "[client#command_thread] Cannot process - Client does not respond to {c}"
                ),
            }
        }
    });
}

async fn listener_thread(listener: NodeListener<()>) {
    tokio::spawn(async move {
        listener.for_each(|event| match event.network() {
            NetEvent::Connected(_, connected) => {
                if !matches!(crate::CONFIG.env, Env::Test) {
                    debug!("[client#on_connect] Are we connected? {}", connected);
                }

                if !connected {
                    // if let Err(e) = crate::BOT.on_disconnect().await {
                    //     error!("[client#on_connect] ❌ {}", e)
                    // };

                    return;
                };

                // if let Err(e) = crate::BOT.on_connect().await {
                //     error!("[client#on_connect] ❌ {}", e)
                // };
            }
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_, incoming_data) => {
                let incoming_data = incoming_data.to_vec();
                debug!("[client#on_message] Incoming data: {:?}", String::from_utf8_lossy(&incoming_data));

                let mut token = lock!(TOKEN_MANAGER);
                if !token.reload().valid() {
                    error!("[client#on_message] ❌ Cannot process inbound message - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
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
                            error!("[client#on_message] ❌ {}", e);
                            return;
                        }
                    };

                let message_type = message.message_type;
                if matches!(message_type, Type::Init) && crate::READY.load(Ordering::SeqCst) {
                    error!("[client#on_message] ❌ Client is already initialized");
                    return;
                }

                // if let Err(e) = crate::BOT.on_message(message) {
                //     error!("[client#on_message] ❌ {}", e)
                // };

                if matches!(message_type, Type::Init) {
                    info!("[client#on_message] Connection established with bot");
                    crate::READY.store(true, Ordering::SeqCst);
                }
            }
            NetEvent::Disconnected(_) => {
                if !matches!(crate::CONFIG.env, Env::Test) {
                    debug!("[client#on_disconnect] Lost connection");
                }

                // if let Err(e) = crate::BOT.on_disconnect().await {
                //     error!("[client#on_disconnect] ❌ {}", e);
                // };
            }
        });
    });
}
