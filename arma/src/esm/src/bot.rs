use crate::token::TokenManager;
use crate::*;

use encryption::*;
use flate2::read::GzDecoder;
use flate2::write::GzEncoder;
use flate2::Compression;
use humantime::format_duration;
use message_io::network::{Endpoint, NetEvent, SendStatus, Transport};
use message_io::node::{self, NodeHandler, NodeListener, NodeTask};
use rand::prelude::*;
use std::cmp::min;
use std::io::prelude::*;
use std::net::ToSocketAddrs;
use std::sync::atomic::AtomicI64;
use std::sync::Mutex as SyncMutex;
use std::time::Duration;
use tokio::sync::mpsc::UnboundedReceiver;
use tokio::time::sleep;

const RECONNECT_MIN: Duration = Duration::from_secs(5); // 5 seconds
const RECONNECT_MAX: Duration = Duration::from_secs(300); // 5 minutes

// Keep the counter in check
const RECONNECT_COUNTER_MAX: i64 =
    (RECONNECT_MAX.as_secs() / RECONNECT_MIN.as_secs()) as i64;

lazy_static! {
    pub static ref TOKEN_MANAGER: Arc<SyncMutex<TokenManager>> =
        Arc::new(SyncMutex::new(TokenManager::new()));
    static ref INIT: Arc<SyncMutex<Init>> =
        Arc::new(SyncMutex::new(Init::default()));
    static ref ENCRYPTION_ENABLED: AtomicBool = AtomicBool::new(false);
    static ref CONNECTED: AtomicBool = AtomicBool::new(false);
    static ref ENDPOINT: Arc<SyncMutex<Option<Endpoint>>> =
        Arc::new(SyncMutex::new(None));
    static ref HANDLER: Arc<SyncMutex<NodeHandler<()>>> = {
        let (handler, _) = node::split();
        Arc::new(SyncMutex::new(handler))
    };
    static ref LISTENER_TASK: Arc<SyncMutex<Option<NodeTask>>> =
        Arc::new(SyncMutex::new(None));
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
    xm8_notification_thread().await;
}

async fn routing_thread(mut receiver: UnboundedReceiver<BotRequest>) {
    tokio::spawn(async move {
        trace!("[routing_thread] Checking for requests");

        loop {
            let Some(request) = receiver.recv().await else {
                continue;
            };

            trace!("[routing_thread] Processing request: {request}");

            match request {
                BotRequest::Connect => {
                    if let Err(errors) = lock!(INIT).validate() {
                        error!("[connect] ❌ Attempted to connect but init data was not valid. Errors: {:?}", errors);
                        continue;
                    }

                    let server_address = crate::CONFIG
                        .connection_uri
                        .to_socket_addrs()
                        .unwrap()
                        .next()
                        .unwrap();

                    info!("[connect] Dialing the bot's number...");

                    match lock!(HANDLER)
                        .network()
                        .connect(Transport::Tcp, server_address)
                    {
                        Ok((e, _)) => {
                            *lock!(ENDPOINT) = Some(e);
                        }
                        Err(e) => {
                            error!("[connect] ❌ Failed to connect to bot - {e}")
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

            if let Err(e) = on_request(incoming_data) {
                error!("[on_request] ❌ {e}");
            }
        }
    });

    *lock!(LISTENER_TASK) = Some(task);
}

async fn xm8_notification_thread() {
    tokio::spawn(async move {
        let time_to_wait = if cfg!(feature = "development") {
            1.0
        } else {
            5.0
        };

        loop {
            sleep(Duration::from_secs_f64(time_to_wait)).await;

            if !crate::READY.load(Ordering::SeqCst) {
                continue;
            }

            let notifications = match DATABASE.get_xm8_notifications().await {
                Ok(n) => n,
                Err(e) => {
                    error!("[xm8_notification_thread] ❌ {e}");
                    continue;
                }
            };

            if notifications.is_empty() {
                continue;
            }

            // Update the attempt counter
            let notification_ids: Vec<&String> =
                notifications.iter().flat_map(|n| &n.uuids).collect();

            if let Err(e) =
                DATABASE.update_xm8_attempt_counter(notification_ids).await
            {
                error!("[xm8_notification_thread] ❌ {e}");
                continue;
            }

            trace!(
                "[xm8_notification_thread] Sending notifications {notifications:?}"
            );

            // Send the message
            let message =
                Message::new().set_type(Type::Call).set_data(Data::from([
                    ("function_name".to_owned(), json!("send_xm8_notification")),
                    ("notifications".to_owned(), json!(notifications)),
                ]));

            if let Err(e) = BotRequest::send(message) {
                error!("[send_to_channel] ❌ {}", e);
            };
        }
    });
}

fn send_message(message: Message) -> ESMResult {
    info!(
        "[send_message] {} - outbound message - {} bytes - data size: {}, metadata size: {}",
        message.id,
        serde_json::to_string(&message.data)
            .unwrap_or_default()
            .len(),
        message.data.len(),
        message.metadata.len(),
    );

    debug!("[send_message] {message}");

    send_request(
        Request::new()
            .set_id(message.id)
            .set_type(RequestType::Message)
            .set_value(message.as_bytes()?),
    )?;

    trace!("[send_message] {} - Sent", message.id);

    Ok(())
}

fn send_request(request: Request) -> ESMResult {
    if !lock!(TOKEN_MANAGER).reload().valid() {
        return Err("❌ Cannot send - Invalid \"esm.key\" detected - Please download your server key from the admin dashboard (https://esmbot.com/dashboard) and place it in \"@esm\"".into());
    }

    // Make sure we are connected first
    if !ready(&*lock!(HANDLER), *lock!(ENDPOINT)) {
        return Err(
            "❌ Cannot send message - We are not connected to the bot at the moment"
                .into(),
        );
    }

    let request = match serde_json::to_vec(&request) {
        Ok(r) => r,
        Err(e) => {
            return Err(
                format!("❌ Cannot send message - Failed to convert - {e}").into()
            )
        }
    };

    // Compress
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());

    if let Err(e) = encoder.write_all(&request[..]) {
        return Err(format!(
            "❌ Cannot send message - Failed to write to buffer - {e}"
        )
        .into());
    };

    let Ok(request) = encoder.finish() else {
        return Err(format!("❌ Cannot send message - Failed to compress").into());
    };

    // Encrypt
    let request = if ENCRYPTION_ENABLED.load(Ordering::SeqCst) {
        encrypt_request(&request, lock!(TOKEN_MANAGER).secret_bytes())
            .map_err(|e| format!("❌ Failed to encrypt. {e}"))?
    } else {
        request
    };

    // Encode
    let mut request = encryption::BASE64_STANDARD.encode(request).into_bytes();

    // Add the length header
    let length = (request.len() as u32).to_be_bytes();
    request.splice(0..0, length);

    // Send
    match lock!(HANDLER)
        .network()
        .send(lock!(ENDPOINT).unwrap(), &request)
    {
        SendStatus::Sent => Ok(()),
        s => Err(format!(
            "❌ Cannot send - We are not connected to the bot at the moment: {s:?}"
        )
        .into()),
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

    if !lock!(TOKEN_MANAGER).reload().valid() {
        error!("❌ Cannot start connection process - Invalid \"esm.key\" detected - Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
        return;
    }

    CONNECTED.store(true, Ordering::SeqCst);

    let request = Request::new()
        .set_type(RequestType::Identification)
        .set_value(lock!(TOKEN_MANAGER).access_bytes().to_vec());

    info!("[on_connect] Attempting to establish a secure connection...");

    if let Err(e) = send_request(request) {
        error!("[on_connect] Error while sending identify request. {e}")
    }
}

fn on_request(incoming_data: Vec<u8>) -> ESMResult {
    let Ok(encoded_message) = String::from_utf8(incoming_data.to_vec()) else {
        return Err("[on_request] ❌ Invalid data received. This is a bug!".into());
    };

    // Decode
    let encoded_message: Vec<u8> = match BASE64_STANDARD.decode(&encoded_message) {
        Ok(p) => p,
        Err(e) => {
            return Err(format!("[on_request] ❌ {e:?}\n{encoded_message:?}").into())
        }
    };

    let decrypted_message =
        decrypt_request(encoded_message, lock!(TOKEN_MANAGER).secret_bytes())
            .map_err(|e| format!("[on_request] ❌ Failed to decrypt. {e}"))?;

    // Decompress
    let mut decoder = GzDecoder::new(decrypted_message.as_slice());
    let mut decoded_message = Vec::new();
    if let Err(e) = decoder.read_to_end(&mut decoded_message) {
        return Err(format!("[on_request] ❌ Failed to decompress: {e:?}").into());
    }

    let request: Request = match serde_json::from_slice(&decoded_message) {
        Ok(r) => r,
        Err(e) => return Err(format!("[on_request] ❌ {e}").into()),
    };

    match request.request_type {
        RequestType::Error => on_error(request),

        RequestType::Handshake => on_handshake(request),

        RequestType::Initialize => on_initialize(request),

        RequestType::Message => on_message(request),

        RequestType::Heartbeat => on_heartbeat(request),

        _ => Ok(()),
    }
}

fn on_disconnect() {
    crate::READY.store(false, Ordering::SeqCst);
    CONNECTED.store(false, Ordering::SeqCst);

    reset_indices();
    reset_session_id();
    ENCRYPTION_ENABLED.store(false, Ordering::SeqCst);

    // Get the current reconnection count and calculate the wait time
    let current_count = RECONNECTION_COUNT.load(Ordering::SeqCst);
    let time_to_wait = if cfg!(feature = "development") {
        Duration::from_millis(500)
    } else {
        // Add jitter of 1-5 seconds to prevent slamming the server all at once
        let jitter = Duration::from_secs_f32(thread_rng().gen_range(1.0..5.0));

        min(RECONNECT_MIN * current_count as u32 + jitter, RECONNECT_MAX)
    };

    warn!(
        "[on_disconnect] ⚠ *Click* Your call with the bot was lost. Attempting to call back in {}",
        format_duration(Duration::from_secs(time_to_wait.as_secs()))
    );

    if current_count <= RECONNECT_COUNTER_MAX {
        RECONNECTION_COUNT.fetch_add(1, Ordering::SeqCst);
    }

    TOKIO_RUNTIME.block_on(async {
        tokio::spawn(async move {
            sleep(time_to_wait).await;

            if let Err(e) = BotRequest::connect() {
                error!("[on_disconnect] ❌ {e}");
            }
        });
    });
}

// Thump
fn on_heartbeat(request: Request) -> ESMResult {
    send_request(request)
}

fn on_error(request: Request) -> ESMResult {
    let message = Message::from_bytes(&request.value)?;

    let error = message
        .errors
        .iter()
        .map(|e| format!("❌ {}", e.error_content))
        .collect::<Vec<String>>()
        .join("\n");

    error!("[on_error] {error}");

    let message = Message::new().set_id(message.id).set_type(Type::Ack);
    send_message(message)?;

    Ok(())
}

fn on_handshake(mut request: Request) -> ESMResult {
    info!("[on_handshake] Performing handshake...");

    if request.value.is_empty() {
        return Err(format!(
            "[on_handshake] Request {:?} contained no data. This is a bug!",
            request
        )
        .into());
    }

    let message = Message::from_bytes(&request.value)?;

    info!("[on_handshake] Good posture ✅");

    // Set the nonce indices
    match message.data.get("indices") {
        Some(serde_json::Value::Array(arr)) => {
            let indices: Vec<u8> = arr
                .iter()
                .filter_map(|i| i.as_u64().map(|n| n as u8))
                .collect();

            if indices.is_empty() {
                return Err("missing_nonce_indices".into());
            }

            // Store the new indices for future use
            if let Err(e) = set_indices(indices.to_owned()) {
                return Err(e.into());
            }
        }
        _ => return Err("missing_nonce_indices".into()),
    }

    info!("[on_handshake] Eye contact ✅");

    // Set the session ID
    match message.data.get("session_id") {
        Some(serde_json::Value::String(session_id)) => {
            if session_id.is_empty() {
                return Err("missing_session_id".into());
            }

            set_session_id(&session_id);
        }
        _ => return Err("missing_session_id".into()),
    }

    info!("[on_handshake] Firm grip ✅");

    let message = message.set_data(Data::default());
    request.value = message.as_bytes()?;

    // Since we've successfully set the nonce indices, we're good to start sending encrypted data
    ENCRYPTION_ENABLED.store(true, Ordering::SeqCst);

    info!("[on_handshake] and laugh at old jokes ✅");

    send_request(request)
}

fn on_initialize(request: Request) -> ESMResult {
    RECONNECTION_COUNT.store(0, Ordering::SeqCst);

    let init = lock!(INIT).clone();

    let message = Message::new()
        .set_id(request.id)
        .set_type(Type::Init)
        .set_data(init.to_data());

    info!(
        "[on_initialize] Introducing ourselves as {}",
        init.server_name
    );

    BotRequest::send(message)
}

fn on_message(request: Request) -> ESMResult {
    if request.value.is_empty() {
        return Err(format!(
            "[on_message] Request {:?} contained no data. This is a bug!",
            request
        )
        .into());
    }

    let message = Message::from_bytes(&request.value)?;

    info!(
        "[on_message] {} - inbound message - {} bytes - data size: {}, metadata size: {}",
        message.id,
        serde_json::to_string(&message.data)
            .unwrap_or_default()
            .len(),
        message.data.len(),
        message.metadata.len(),
    );

    debug!("[on_message] {}", message);

    match message.message_type {
        Type::Query => ArmaRequest::query(message),
        Type::Call => ArmaRequest::call("call_function", message),
        Type::PostInit => {
            if crate::READY.load(Ordering::SeqCst) {
                return Err("[post_init] ❌ Client is already initialized".into());
            }

            info!("[post_init] Handshake accepted");

            ArmaRequest::call("post_initialization", message)
        }
        Type::Echo => BotRequest::send(message),
        Type::Search => ArmaRequest::search(message),
        t => Err(format!("❌ Unexpected message type: {t:?}").into()),
    }
}
