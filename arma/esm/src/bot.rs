use crate::router::RoutingRequest;
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
    static ref INIT: Arc<SyncMutex<Init>> = Arc::new(SyncMutex::new(Init::default()));
    static ref PING_RECEIVED: AtomicBool = AtomicBool::new(false);
    static ref CONNECTED: AtomicBool = AtomicBool::new(false);
    static ref ENDPOINT: Arc<SyncMutex<Option<Endpoint>>> = Arc::new(SyncMutex::new(None));
    static ref HANDLER: Arc<SyncMutex<NodeHandler<NetworkSignal>>> = {
        let (handler, _) = node::split();
        Arc::new(SyncMutex::new(handler))
    };
}

enum NetworkSignal {
    Init,
}

pub async fn initialize(receiver: UnboundedReceiver<RoutingRequest>) {
    trace!("[bot::initialize] Loading token");

    if let Err(e) = lock!(TOKEN_MANAGER).load() {
        error!("[bot#initialize] ❌ {}", e);
    };

    let (handler, listener) = node::split::<NetworkSignal>();
    *lock!(HANDLER) = handler;

    routing_thread(receiver).await;
    listener_thread(listener).await;
    heartbeat_thread().await;
}

async fn routing_thread(mut receiver: UnboundedReceiver<RoutingRequest>) {
    trace!("[bot::routing_thread] Spawning");

    tokio::spawn(async move {
        trace!("[bot::routing_thread] Receiving");
        loop {
            let Some(request) = receiver.recv().await else {
                continue;
            };

            debug!("[bot::routing_thread] Processing request: {request}");
            match request {
                RoutingRequest::Connect => {
                    tokio::spawn(async {
                        trace!("[bot::routing_thread] Connect");

                        if let Err(errors) = lock!(INIT).validate() {
                            error!("[bot::routing_thread] ❌ Attempted to connect but init data was not valid. Errors: {:?}", errors);
                            return;
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

                        let handler = lock!(HANDLER);
                        match handler
                            .network()
                            .connect(Transport::FramedTcp, server_address)
                        {
                            Ok((e, _)) => {
                                *lock!(ENDPOINT) = Some(e);
                                handler.signals().send(NetworkSignal::Init);
                            }
                            Err(e) => {
                                error!(
                                    "[bot::routing_thread] ❌ Failed to connect to esm_bot - {e}"
                                );
                            }
                        };
                    });
                }
                RoutingRequest::Send(message) => {
                    tokio::spawn(async {
                        trace!("[bot::routing_thread] Send");
                        match send_to_bot(*message) {
                            Ok(_) => trace!("[bot#send_to_bot] Sent"),
                            Err(e) => error!("[bot#send_to_bot] {e}"),
                        }
                    });
                }

                RoutingRequest::ClientInitialize { init } => {
                    tokio::spawn(async {
                        trace!("[bot::routing_thread] ClientInitialize");

                        *lock!(INIT) = init;

                        // Now that we have the init data, tell ourselves to try to connect
                        if let Err(e) = crate::ROUTER.route("bot", RoutingRequest::Connect) {
                            error!("[bot::routing_thread] ❌ {e}");
                        }
                    });
                }
                c => {
                    error!("[bot::routing_thread] Cannot process - Client does not respond to {c}")
                }
            }
            debug!("[bot::routing_thread] DONE");
        }
    });
}

async fn listener_thread(listener: NodeListener<NetworkSignal>) {
    trace!("[bot::listener_thread] Spawning");

    tokio::spawn(async move {
        listener.for_each(|event| match event {
            node::NodeEvent::Network(event) => match event {
                NetEvent::Accepted(_, _) => unreachable!(),
                NetEvent::Connected(_, connected) => match on_connect(connected) {
                    Ok(_) => (),
                    Err(e) => error!("[bot#on_connect] {e}"),
                },
                NetEvent::Disconnected(_) => match on_disconnect() {
                    Ok(_) => (),
                    Err(e) => error!("[bot#on_disconnect] {e}"),
                },
                NetEvent::Message(_, incoming_data) => match on_message(incoming_data) {
                    Ok(_) => (),
                    Err(e) => error!("[bot#on_message] {e}"),
                },
            },
            node::NodeEvent::Signal(signal) => match signal {
                NetworkSignal::Init => {
                    let message =
                        Message::new(Type::Init).set_data(Data::Init(lock!(INIT).clone()));

                    if let Err(e) = crate::ROUTER.route_to_bot(message) {
                        error!("[bot#listener_thread] Error while sending init message. {e}")
                    }
                }
            },
        });
    });
}

async fn heartbeat_thread() {
    tokio::spawn(async {
        info!("[heartbeat] ✅");
    });
}

fn send_to_bot(mut message: Message) -> ESMResult {
    let mut token = lock!(TOKEN_MANAGER).clone();
    if !token.reload().valid() {
        return Err("❌ Cannot send - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
    }

    // Add the server ID if there is none
    if message.server_id.is_none() {
        message.server_id = Some(token.id_bytes().to_vec());
    }

    if !matches!(message.message_type, Type::Init) {
        debug!("[bot#send_to_bot] {}", message);
    }

    // Convert the message to bytes so it can be sent
    let bytes = match message.as_bytes(token.key_bytes()) {
        Ok(bytes) => bytes,
        Err(error) => return Err(format!("❌ {error}").into()),
    };

    let endpoint = *lock!(ENDPOINT);
    let handler = lock!(HANDLER);

    // Make sure we are connected first
    if !ready(&handler, endpoint) {
        return Err(
            "❌ Cannot send message - We are not connected to the bot at the moment".into(),
        );
    }

    match handler.network().send(endpoint.unwrap(), &bytes) {
        SendStatus::Sent => {
            debug!("After send");
            Ok(())
        }
        SendStatus::MaxPacketSizeExceeded => Err(format!(
            "❌ Cannot send - Message is too large. Size: {}. Message: {message:?}",
            bytes.len()
        )
        .into()),
        s => Err(
            format!("❌ Cannot send - We are not connected to the bot at the moment: {s:?}").into(),
        ),
    }
}

fn ready(handler: &NodeHandler<NetworkSignal>, endpoint: Option<Endpoint>) -> bool {
    if endpoint.is_none() {
        error!("Endpoint is none");
        return false;
    }

    if !CONNECTED.load(Ordering::SeqCst) {
        error!("Not connected");
        return false;
    }

    if !handler.is_running() {
        error!("handler is not running");
        return false;
    }

    match handler.network().is_ready(endpoint.unwrap().resource_id()) {
        Some(b) => match b {
            true => true,
            false => {
                error!("Endpoint not connected");
                false
            }
        },
        None => {
            error!("Endpoint not has been disconnected");
            false
        }
    }
}

fn on_connect(connected: bool) -> ESMResult {
    if !matches!(crate::CONFIG.env, Env::Test) {
        debug!("[bot#on_connect] Are we connected? {}", connected);
    }

    if !connected {
        return on_disconnect();
    };

    CONNECTED.store(true, Ordering::SeqCst);
    Ok(())
}

fn on_message(incoming_data: &[u8]) -> ESMResult {
    let mut token = lock!(TOKEN_MANAGER);
    if !token.reload().valid() {
        return Err("❌ Cannot process inbound message - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
    }

    let message = match Message::from_bytes(incoming_data, token.key_bytes()) {
        Ok(message) => {
            drop(token);
            debug!("[bot#on_message] {message}");
            message
        }
        Err(e) => return Err(format!("❌ {e}").into()),
    };

    if !message.errors.is_empty() {
        let error = message
            .errors
            .iter()
            .map(|e| format!("❌ {}", e.error_content))
            .collect::<Vec<String>>()
            .join("\n");

        return Err(error.into());
    }

    match message.message_type {
        Type::Init => {
            if crate::READY.load(Ordering::SeqCst) {
                return Err("❌ Client is already initialized".into());
            }

            crate::ROUTER.route_to_arma("post_initialization", message)
        }
        Type::Query => crate::ROUTER.route_to_arma("query", message),
        Type::Arma => crate::ROUTER.route_to_arma("call_function", message),
        Type::Test => crate::ROUTER.route_to_bot(message),
        Type::Ping => crate::ROUTER.route_to_bot(message.set_type(Type::Pong)),
        _ => Err(format!(
            "❌ Message type \"{:?}\" has not been implemented yet",
            message.message_type
        )
        .into()),
    }
}

fn on_disconnect() -> ESMResult {
    if !matches!(crate::CONFIG.env, Env::Test) {
        debug!("[bot#on_disconnect] Lost connection");
    }

    CONNECTED.store(false, Ordering::SeqCst);
    crate::READY.store(false, Ordering::SeqCst);

    if let Err(e) = crate::ROUTER.route("bot", RoutingRequest::Connect) {
        error!("[bot::routing_thread] ❌ {e}");
    }

    Ok(())
}
