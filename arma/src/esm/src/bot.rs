use crate::token::TokenManager;
use crate::*;

use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeListener, NodeTask};
use std::net::ToSocketAddrs;
use std::sync::atomic::AtomicI64;
use std::sync::Mutex as SyncMutex;
use std::time::Duration;
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    pub static ref TOKEN_MANAGER: Arc<SyncMutex<TokenManager>> =
        Arc::new(SyncMutex::new(TokenManager::new()));
    static ref INIT: Arc<SyncMutex<Init>> = Arc::new(SyncMutex::new(Init::default()));
    static ref PING_RECEIVED: AtomicBool = AtomicBool::new(false);
    static ref CONNECTED: AtomicBool = AtomicBool::new(false);
    static ref ENDPOINT: Arc<SyncMutex<Option<Endpoint>>> = Arc::new(SyncMutex::new(None));
    static ref HANDLER: Arc<SyncMutex<NodeHandler<()>>> = {
        let (handler, _) = node::split();
        Arc::new(SyncMutex::new(handler))
    };
    static ref LISTENER_TASK: Arc<SyncMutex<Option<NodeTask>>> = Arc::new(SyncMutex::new(None));
    static ref RECONNECTION_COUNT: AtomicI64 = AtomicI64::new(0);
}

pub async fn initialize(receiver: UnboundedReceiver<BotRequest>) {
    trace!("[initialize] Loading token");

    if let Err(e) = lock!(TOKEN_MANAGER).load() {
        error!("[initialize] ❌ {}", e);
    };

    trace!("[initialize] Loading network");
    let (handler, listener) = node::split::<()>();
    *lock!(HANDLER) = handler;

    trace!("[initialize] Loading threads");
    routing_thread(receiver).await;
    listener_thread(listener);
}

async fn routing_thread(mut receiver: UnboundedReceiver<BotRequest>) {
    tokio::spawn(async move {
        loop {
            let Some(request) = receiver.recv().await else {
                continue;
            };

            trace!("[routing_thread] Processing request: {request}");

            match request {
                BotRequest::Connect => {
                    if let Err(errors) = lock!(INIT).validate() {
                        error!("[connect] ❌ Attempted to connect but init data was not valid. Errors: {:?}", errors);
                        return;
                    }

                    let server_address = crate::CONFIG
                        .connection_url
                        .to_socket_addrs()
                        .unwrap()
                        .next()
                        .unwrap();

                    if !matches!(crate::CONFIG.env, Env::Test) {
                        warn!("[connect] Attempting to connect to esm_bot at {server_address}");
                    }

                    match lock!(HANDLER)
                        .network()
                        .connect(Transport::FramedTcp, server_address)
                    {
                        Ok((e, _)) => {
                            *lock!(ENDPOINT) = Some(e);
                        }
                        Err(e) => {
                            error!("[connect] ❌ Failed to connect to esm_bot - {e}")
                        }
                    }
                }

                BotRequest::Send(message) => match send_message(*message) {
                    Ok(_) => (),
                    Err(e) => error!("[send] {e}"),
                },

                BotRequest::Initialize(init) => {
                    *lock!(INIT) = init;

                    // Now that we have the init data, tell ourselves to try to connect
                    if let Err(e) = BotRequest::connect() {
                        error!("[initialize] ❌ {e}");
                    }
                }
            }
        }
    });
}

fn listener_thread(listener: NodeListener<()>) {
    let task = listener.for_each_async(|event| match event.network() {
        NetEvent::Accepted(_, _) => unreachable!(),
        NetEvent::Connected(_, connected) => on_connect(connected),
        NetEvent::Disconnected(_) => on_disconnect(),

        NetEvent::Message(_, incoming_data) => {
            let incoming_data = incoming_data.to_owned();

            if let Err(e) = on_message(incoming_data) {
                error!("[on_message] {e}");
            }
        }
    });

    *lock!(LISTENER_TASK) = Some(task);
}

fn send_message(message: Message) -> ESMResult {
    if !lock!(TOKEN_MANAGER).reload().valid() {
        return Err("❌ Cannot send - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
    }

    match message.message_type {
        Type::Event => (),
        _ => debug!("[send] {}", message),
    }

    // Convert the message to bytes so it can be sent
    let bytes = match message.as_bytes(lock!(TOKEN_MANAGER).secret_bytes()) {
        Ok(bytes) => bytes,
        Err(error) => return Err(format!("❌ {error}").into()),
    };

    send_request(ServerRequest {
        request_type: "m".into(),
        content: bytes,
    })?;

    trace!("[send] {} - Sent", message.id);

    Ok(())
}

fn send_request(request: ServerRequest) -> ESMResult {
    // Make sure we are connected first
    if !ready(&*lock!(HANDLER), *lock!(ENDPOINT)) {
        return Err(
            "❌ Cannot send message - We are not connected to the bot at the moment".into(),
        );
    }

    let request = match serde_json::to_vec(&request) {
        Ok(r) => r,
        Err(e) => return Err(format!("❌ Cannot send message - Failed to convert - {e}").into()),
    };

    match lock!(HANDLER)
        .network()
        .send(lock!(ENDPOINT).unwrap(), &request)
    {
        SendStatus::Sent => Ok(()),
        SendStatus::MaxPacketSizeExceeded => Err(format!(
            "❌ Cannot send - Message is too large - Size: {}",
            request.len()
        )
        .into()),
        s => Err(
            format!("❌ Cannot send - We are not connected to the bot at the moment: {s:?}").into(),
        ),
    }
}

fn ready(handler: &NodeHandler<()>, endpoint: Option<Endpoint>) -> bool {
    if endpoint.is_none() {
        trace!("[ready] Endpoint is none");
        return false;
    }

    if !handler.is_running() {
        trace!("[ready] Handler is not running");
        return false;
    }

    if !CONNECTED.load(Ordering::SeqCst) {
        trace!("[ready] Not connected");
        return false;
    }

    match handler.network().is_ready(endpoint.unwrap().resource_id()) {
        Some(b) => match b {
            true => true,
            false => {
                trace!("[ready] Endpoint not connected");
                false
            }
        },
        None => {
            trace!("[ready] Endpoint not has been disconnected");
            false
        }
    }
}

fn on_connect(connected: bool) {
    trace!("[on_connect] Are we connected? {connected}");

    // Make sure we are connected first
    if !connected {
        on_disconnect();
        return;
    };

    CONNECTED.store(true, Ordering::SeqCst);
    RECONNECTION_COUNT.store(0, Ordering::SeqCst);
}

fn on_message(incoming_data: Vec<u8>) -> ESMResult {
    let request: ServerRequest = match serde_json::from_slice(&incoming_data) {
        Ok(r) => r,
        Err(e) => return Err(format!("❌ {e}").into()),
    };

    match request.request_type.as_str() {
        // Identify
        "id" => send_request(ServerRequest {
            request_type: "id".into(),
            content: lock!(TOKEN_MANAGER).access_bytes().to_vec(),
        }),

        // Initialize
        "i" => {
            info!("[bot_initialize] Attempting to phone home like its 1982. Please hold...");

            let message = Message::new().set_data(Data::Init(lock!(INIT).clone()));

            if let Err(e) = BotRequest::send(message) {
                error!("[listener_thread] Error while sending init message. {e}")
            }

            Ok(())
        }

        // Message
        _ => {
            let mut token = lock!(TOKEN_MANAGER);
            if !token.reload().valid() {
                return Err("❌ Cannot process inbound message - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).".into());
            }

            let message = match Message::from_bytes(&request.content, token.secret_bytes()) {
                Ok(message) => {
                    if !matches!(message.data, Data::Ping) {
                        info!(
                            "[on_message] {} - {:?} - {}",
                            message.id,
                            message.message_type,
                            message.data.name(),
                        );

                        debug!("[on_message] {message:?}");
                    }

                    message
                }
                Err(e) => return Err(format!("❌ {e}").into()),
            };

            // Echo bypasses this so errors can be triggered on the round trip
            if !matches!(message.message_type, Type::Echo) && !message.errors.is_empty() {
                let error = message
                    .errors
                    .iter()
                    .map(|e| format!("❌ {}", e.error_content))
                    .collect::<Vec<String>>()
                    .join("\n");

                return Err(error.into());
            }

            match message.message_type {
                Type::Query => ArmaRequest::query(message),
                Type::Arma => ArmaRequest::call("call_function", message),
                Type::Event => match message.data {
                    Data::PostInit(_) => {
                        if crate::READY.load(Ordering::SeqCst) {
                            return Err("❌ Client is already initialized".into());
                        }

                        info!("[bot_initialization] Hand shake complete. Good posture ✅, eye contact ✅, and a firm grip ✅");
                        ArmaRequest::call("post_initialization", message)
                    }
                    Data::Ping => BotRequest::send(message.set_data(Data::Pong)),
                    t => Err(format!("❌ Unexpected event type: {t:?}").into()),
                },
                Type::Echo => BotRequest::send(message),
            }
        }
    }
}

fn on_disconnect() {
    CONNECTED.store(false, Ordering::SeqCst);
    crate::READY.store(false, Ordering::SeqCst);

    // Get the current reconnection count and calculate the wait time
    let current_count = RECONNECTION_COUNT.load(Ordering::SeqCst);
    let time_to_wait: f32 = match crate::CONFIG.env {
        Env::Test => 0.5,
        Env::Development => 3_f32,
        _ => (current_count * 15) as f32,
    };

    let time_to_wait = Duration::from_secs_f32(time_to_wait);
    warn!(
        "[on_disconnect] ⚠ *Click* Your call with the bot was lost. Attempting to call back in {:?}",
        time_to_wait
    );

    // Sleep a max of 5 minutes
    if current_count <= 20 {
        // Increase the reconnect counter by 1
        RECONNECTION_COUNT.fetch_add(1, Ordering::SeqCst);
    }

    std::thread::sleep(time_to_wait);

    if let Err(e) = BotRequest::connect() {
        error!("[on_disconnect] ❌ {e}");
    }
}
