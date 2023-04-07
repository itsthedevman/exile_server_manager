use crate::{client_manager::ClientManager, *};

use message_io::{
    network::{NetEvent, Transport},
    node::{self, NodeHandler, NodeListener, NodeTask},
};
use std::{sync::atomic::Ordering, time::Duration};
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    static ref LISTENER_TASK: Arc<Mutex<Option<NodeTask>>> = Arc::new(Mutex::new(None));
}

pub type Handler = NodeHandler<()>;

const HEARTBEAT_WAIT_MS: u64 = 1500;

pub async fn initialize(receiver: UnboundedReceiver<ServerRequest>) {
    let (handler, listener) = node::split::<()>();

    // Start listening
    match handler.network().listen(
        Transport::FramedTcp,
        format!("0.0.0.0:{}", crate::SERVER_PORT),
    ) {
        Ok((_resource_id, real_addr)) => {
            info!("[initialize] ✅ Listening on port {real_addr}");
            crate::SERVER_READY.store(true, Ordering::SeqCst)
        }
        Err(e) => panic!("[initialize] Failed to start server. {}", e),
    }

    routing_thread(handler, receiver).await;
    listener_thread(listener).await;
    heartbeat_thread().await;
}

async fn routing_thread(handler: Handler, mut receiver: UnboundedReceiver<ServerRequest>) {
    tokio::spawn(async move {
        info!("[routing_thread] ✅");

        let mut client_manager = ClientManager::new();

        let ready = || {
            crate::BOT_CONNECTED.load(Ordering::SeqCst)
                && crate::SERVER_READY.load(Ordering::SeqCst)
        };

        loop {
            let Some(request) = receiver.recv().await else {
                error!("[routing_thread] Receiver has been dropped!");
                continue;
            };

            if !matches!(request, ServerRequest::AliveCheck) {
                debug!("[routing_thread] Processing request: {:?}", request);
            }

            match request {
                /////////////////////
                // Bot requests
                /////////////////////
                ServerRequest::Resume => crate::SERVER_READY.store(true, Ordering::SeqCst),
                ServerRequest::Pause => {
                    crate::SERVER_READY.store(false, Ordering::SeqCst);
                    client_manager.disconnect_all(&handler);
                }

                ServerRequest::Disconnect(server_uuid) => match server_uuid {
                    Some(uuid) => {
                        let Some(client) = client_manager.get_by_uuid(&uuid) else {
                            error!("[disconnect] {} - Failed to retrieve client", uuid);
                            continue;
                        };

                        client.disconnect(&handler);
                        client_manager.remove(client.host());
                    }
                    None => client_manager.disconnect_all(&handler),
                },

                ServerRequest::Send {
                    server_uuid,
                    mut message,
                } => {
                    let Some(client) = client_manager.get_by_uuid(&server_uuid) else {
                        error!("[send] {} - Failed to retrieve client", server_uuid);

                        let message = message.add_error_code("client_not_connected");
                        if let Err(e) = BotRequest::send(message, Some(server_uuid)) {
                            error!("[send] {} - Failed to send error - {e}", server_uuid);
                        }

                        continue;
                    };

                    if let Err(e) = client.send_message(&handler, message.as_mut()).await {
                        error!("{e}");

                        let message = message.add_error_code("client_not_connected");
                        if let Err(e) = BotRequest::send(message, Some(server_uuid)) {
                            error!("[send] {} - Failed to send error - {e}", server_uuid);
                        }
                    }
                }

                /////////////////////
                // Internal requests
                /////////////////////
                ServerRequest::AliveCheck => client_manager.alive_check(&handler).await,

                ServerRequest::DisconnectEndpoint(endpoint) => {
                    let Some(client) = client_manager.get(endpoint) else {
                        error!("[disconnect_endpoint] {} - Failed to retrieve client", endpoint.addr());
                        continue;
                    };

                    client.disconnect(&handler);
                    client_manager.remove(client.host());
                }

                ServerRequest::OnConnect(endpoint) => {
                    trace!(
                        "[listener_thread] {} - accepted - are we ready? {}",
                        endpoint.addr(),
                        ready()
                    );

                    let client = client_manager.add(endpoint);

                    if !ready() {
                        client.disconnect(&handler);
                        client_manager.remove(endpoint.addr());

                        continue;
                    }

                    info!("[on_connect] \"{}\" - Requesting identity", client.host());

                    // Connection step 1
                    if let Err(e) = client.request_identity(&handler) {
                        error!("[on_connect] {e}");
                    }
                }

                ServerRequest::OnMessage { endpoint, bytes } => {
                    let Some(client) = client_manager.get_mut(endpoint) else {
                        error!("[on_message] {} - Failed to retrieve client", endpoint.addr());
                        continue;
                    };

                    if !ready() {
                        client.disconnect(&handler);
                        client_manager.remove(endpoint.addr());
                        continue;
                    }

                    let request: ClientRequest = match serde_json::from_slice(&bytes) {
                        Ok(r) => r,
                        Err(e) => {
                            error!(
                                "[on_message] {} - {} - Failed to convert message from bytes - {e}. {bytes:?}",
                                client.host(),
                                client.server_uuid
                            );

                            client.disconnect(&handler);
                            client_manager.remove(endpoint.addr());
                            continue;
                        }
                    };

                    // Connection step 2
                    if request.request_type.as_str() == "id" {
                        if let Err(e) = client.set_token_data(&request.content) {
                            error!(
                                "[on_message] {} - {} - set_token_data - {e}",
                                client.host(),
                                String::from_utf8_lossy(&request.content)
                            );
                            continue;
                        }

                        info!("[on_message] \"{}\" - Requesting init", client.host());

                        // Connection step 3
                        if let Err(e) = client.request_init(&handler) {
                            error!(
                                "[on_message] {} - {} - request_init - {e}",
                                client.host(),
                                client.server_uuid
                            );
                        }
                        continue;
                    }

                    // The client has to encrypt the message with the same server key as the Id
                    // Which means that if it fails to decrypt, the message was invalid and the endpoint is disconnected
                    // It is safe to assume this endpoint is who they say they are if this doesn't error
                    let message = match client.parse_message(&request.content).await {
                        Ok(message) => match message {
                            Some(m) => m,
                            None => continue,
                        },
                        Err(_e) => {
                            client.disconnect(&handler);
                            client_manager.remove(endpoint.addr());

                            continue;
                        }
                    };

                    info!(
                        "[on_message] {address} - {server_id} - {message_id} - {message_type:?}/{status} - {message_data:?}",
                        address = endpoint.addr(),
                        message_id = message.id,
                        server_id = client.server_uuid,
                        message_type = message.message_type,
                        message_data = message.data,
                        status = if message.errors.is_empty() {
                            "Success"
                        } else {
                            "Failed"
                        }
                    );

                    if let Err(e) = BotRequest::send(message, Some(client.server_uuid)) {
                        error!(
                            "[on_message] {} - {} - {e}",
                            client.host(),
                            client.server_uuid
                        );

                        client.disconnect(&handler);
                        client_manager.remove(endpoint.addr());
                    }
                }
                ServerRequest::OnDisconnect(endpoint) => {
                    let Some(client) = client_manager.get_mut(endpoint) else {
                        error!("[on_disconnect] {} - Failed to retrieve client", endpoint.addr());
                        continue;
                    };

                    debug!("[on_disconnect] {} - {}", client.host(), client.server_uuid);

                    // The alive check will remove the client for us
                    client.connected = false;

                    if let Err(e) = BotRequest::disconnected(client.server_uuid) {
                        error!("{e}");
                    }
                }
            }
        }
    });
}

async fn listener_thread(listener: NodeListener<()>) {
    tokio::spawn(async move {
        let task = listener.for_each_async(move |event| match event.network() {
            NetEvent::Connected(_, _) => unreachable!(), // Unused
            NetEvent::Accepted(endpoint, _resource_id) => {
                if let Err(e) = ServerRequest::on_connect(endpoint) {
                    error!("[listener_thread] Failed to route on_connect to server on Accepted event. {e}")
                }
            }
            NetEvent::Disconnected(endpoint) => {
                if let Err(e) = ServerRequest::on_disconnect(endpoint) {
                    error!("[listener_thread] Failed to route endpoint to server on Disconnected event. {e}")
                }
            },
            NetEvent::Message(endpoint, message_bytes) => {
                if let Err(e) = ServerRequest::on_message(endpoint, message_bytes){
                    error!("[listener_thread] Failed to route on_message to server on Message event. {e}")
                }
            }
        });

        *lock!(LISTENER_TASK) = Some(task);

        info!("[listener_thread] ✅");
    });
}

async fn heartbeat_thread() {
    tokio::spawn(async {
        info!("[heartbeat_thread] ✅");

        loop {
            tokio::time::sleep(Duration::from_millis(HEARTBEAT_WAIT_MS)).await;

            if let Err(e) = ServerRequest::alive_check() {
                error!("[heartbeat_thread] Failed to route alive_check to server - {e}")
            }
        }
    });
}
