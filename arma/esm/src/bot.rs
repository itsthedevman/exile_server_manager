use crate::router::RoutingCommand;
use crate::token::TokenManager;
use crate::*;

use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeListener};
use std::net::ToSocketAddrs;
use std::sync::Mutex as SyncMutex;
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    pub static ref TOKEN_MANAGER: Arc<SyncMutex<TokenManager>> =
        Arc::new(SyncMutex::new(TokenManager::new()));
}

pub async fn initialize(receiver: UnboundedReceiver<RoutingCommand>) {
    trace!("[bot::initialize] Loading token");

    if let Err(e) = lock!(TOKEN_MANAGER).load() {
        error!("[bot#initialize] ❌ {}", e);
    };

    let (handler, listener) = node::split::<()>();

    command_thread(receiver, handler).await;
    listener_thread(listener).await;
}

fn send_to_bot(mut message: Message, handler: &NodeHandler<()>, endpoint: Endpoint) -> ESMResult {
    let mut token = lock!(TOKEN_MANAGER);
    if !token.reload().valid() {
        return Err("[bot#send_to_bot] Cannot send - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
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
                debug!("[bot#send_to_bot] {}", message);
            }

            match handler.network().send(endpoint, &bytes) {
                SendStatus::Sent => {
                    debug!("After send");
                    Ok(())
                },
                SendStatus::MaxPacketSizeExceeded => Err(format!(
                    "[bot#send_to_bot] Cannot send - Message is too large. Size: {}. Message: {message:?}", bytes.len()
                )
                .into()),
                _ => Err("[bot#send_to_bot] Cannot send - We are not connected to the bot at the moment".into()),
            }
        }
        Err(error) => Err(format!("[bot#send_to_bot] {error}").into()),
    }
}

async fn command_thread(mut receiver: UnboundedReceiver<RoutingCommand>, handler: NodeHandler<()>) {
    trace!("[bot::command_thread] Spawning");

    tokio::spawn(async move {
        // Setting up the values because this code doesn't receive certain things until extension#pre_init
        let mut arma_init: Init = Init::default();
        let mut endpoint: Option<Endpoint> = None;

        let ready = |handler: &NodeHandler<()>, endpoint: &Option<Endpoint>| -> bool {
            if endpoint.is_none() {
                return false;
            }

            let endpoint = endpoint.as_ref().unwrap();
            matches!(
                handler.network().is_ready(endpoint.resource_id()),
                Some(true)
            )
        };

        // Command loop
        trace!("[bot::command_thread] Receiving");
        while let Some(command) = receiver.recv().await {
            match command {
                RoutingCommand::Connect => {
                    trace!("[bot#command_thread] Connect");

                    if let Err(errors) = arma_init.validate() {
                        error!("[bot#command_thread] ❌ Attempted to connect but init data was not valid. Errors: {:?}", errors);
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
                            "[bot#connect] Attempting to connect to esm_bot at {server_address}"
                        );
                    }

                    match handler
                        .network()
                        .connect(Transport::FramedTcp, server_address)
                    {
                        Ok((e, _)) => endpoint = Some(e),
                        Err(e) => {
                            error!("[bot#command_thread] ❌ Failed to connect to server - {e}");
                            continue;
                        }
                    };

                    let mut message = Message::new(Type::Init);
                    message.data = Data::Init(arma_init.clone());

                    debug!("[bot#command_thread] Initialization {:#?}", message);

                    if let Err(e) = crate::ROUTER.route_to_bot(message) {
                        error!("[bot#command_thread] ❌ {}", e);
                    }
                }
                RoutingCommand::Send { message, delay } => {
                    trace!("[bot#command_thread] Send");

                    // Make sure we are connected first
                    if ready(&handler, &endpoint) {
                        error!("[bot#command_thread] Cannot send message - Not connected to bot");
                        continue;
                    }

                    // If there is a delay, just spawn it off and re-route the message back after waiting
                    if let Some(d) = delay {
                        tokio::spawn(async move {
                            tokio::time::sleep(d).await;

                            if let Err(e) = crate::ROUTER.route_to_bot(*message) {
                                error!("[bot#command_thread] ❌ {e}");
                            };
                        });
                    } else if let Err(e) = send_to_bot(*message, &handler, endpoint.unwrap()) {
                        error!("{e}");
                    }
                }
                RoutingCommand::ClientInitialize { init } => {
                    trace!("[bot#command_thread] ClientInitialize");

                    arma_init = init;

                    // Now that we have the init data, tell ourselves to try to connect
                    if let Err(e) = crate::ROUTER.route_internal("bot", RoutingCommand::Connect) {
                        error!("[bot#command_thread] ❌ {e}");
                    }
                }
                c => error!("[bot#command_thread] Cannot process - Client does not respond to {c}"),
            }
        }
    });
}

async fn listener_thread(listener: NodeListener<()>) {
    trace!("[bot::listener_thread] Spawning");

    tokio::spawn(async move {
        listener.for_each(|event| match event.network() {
            NetEvent::Connected(_, connected) => on_connect(connected),
            NetEvent::Accepted(_, _) => unreachable!(),
            NetEvent::Message(_, incoming_data) => on_message(incoming_data.to_vec()),
            NetEvent::Disconnected(_) => on_disconnect(),
        });
    });
}

fn on_connect(connected: bool) {
    if !matches!(crate::CONFIG.env, Env::Test) {
        debug!("[bot#on_connect] Are we connected? {}", connected);
    }

    if !connected {
        on_disconnect();
        return;
    };

    // self.connection_manager
    //         .connected
    //         .store(true, Ordering::SeqCst);
}

fn on_message(incoming_data: Vec<u8>) {
    debug!(
        "[bot#on_message] Incoming data: {:?}",
        String::from_utf8_lossy(&incoming_data)
    );

    let mut token = lock!(TOKEN_MANAGER);
    if !token.reload().valid() {
        error!("[bot#on_message] ❌ Cannot process inbound message - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
        return;
    }

    let message = match Message::from_bytes(incoming_data, token.key_bytes()) {
        Ok(message) => {
            drop(token);
            debug!("[bot#on_message] {message}");
            message
        }
        Err(e) => {
            error!("[bot#on_message] ❌ {}", e);
            return;
        }
    };

    if !message.errors.is_empty() {
        for error in message.errors {
            error!("[bot#on_message] ❌ {}", error.error_content);
        }

        return;
    }

    let message_type = message.message_type;
    if matches!(message_type, Type::Init) && crate::READY.load(Ordering::SeqCst) {
        error!("[bot#on_message] ❌ Client is already initialized");
        return;
    }

    if let Err(e) = process_message(message) {
        error!("[bot#on_message] ❌ {e}");
    }
}

fn on_disconnect() {
    if !matches!(crate::CONFIG.env, Env::Test) {
        debug!("[bot#on_disconnect] Lost connection");
    }

    // self.connection_manager
    //         .connected
    //         .store(false, Ordering::SeqCst);

    crate::READY.store(false, Ordering::SeqCst);
}

fn process_message(message: Message) -> ESMResult {
    match message.message_type {
        Type::Init => crate::ROUTER.route_to_arma("post_initialization", message),
        Type::Query => crate::ROUTER.route_to_arma("query", message),
        Type::Arma => crate::ROUTER.route_to_arma("call_function", message),
        Type::Test => crate::ROUTER.route_to_bot(message),
        _ => Err(format!(
            "[bot#on_message] ❌ Message type \"{:?}\" has not been implemented yet",
            message.message_type
        )
        .into()),
    }
}
