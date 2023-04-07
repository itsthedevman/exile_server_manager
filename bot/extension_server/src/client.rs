use chrono::{DateTime, Utc};
use message_io::network::{Endpoint, ResourceId, SendStatus};
use uuid::Uuid;

use crate::server::Handler;
use crate::*;

#[derive(Debug, Clone)]
pub struct Client {
    pub endpoint: Endpoint,
    pub resource_id: ResourceId,
    pub last_checked_at: DateTime<Utc>,
    pub pong_received: bool,
    pub connected: bool,
    pub server_uuid: Uuid,
}

impl Client {
    pub async fn get_server_key(server_uuid: &Uuid) -> Option<Vec<u8>> {
        let database = await_lock!(DATABASE);
        let Some(client) = database.as_ref() else {
            error!("");
            return None;
        };

        match client
            .query(
                "SELECT server_key FROM servers WHERE uuid = $1",
                &[&server_uuid],
            )
            .await
        {
            Ok(rows) => {
                if rows.is_empty() {
                    // error!("[get_server_key] {server_id} - Server does not exist");
                    return None;
                }

                match rows[0].try_get::<usize, String>(0) {
                    Ok(r) => Some(r.as_bytes().to_owned()),
                    Err(e) => {
                        error!("[get_server_key] {server_uuid} - Failed to get server_key - {e}");
                        None
                    }
                }
            }
            Err(e) => {
                error!("[get_server_key] {server_uuid} - Error occurred while querying for server_key - {e}");
                None
            }
        }
    }

    pub fn new(endpoint: Endpoint) -> Self {
        Client {
            endpoint,
            resource_id: endpoint.resource_id(),
            server_uuid: Uuid::new_v4(),
            last_checked_at: Utc::now(),
            pong_received: true,
            connected: true,
        }
    }

    pub fn host(&self) -> std::net::SocketAddr {
        self.endpoint.addr()
    }

    pub fn set_token_data(&mut self, server_uuid: &[u8]) -> Result<(), uuid::Error> {
        let uuid = String::from_utf8_lossy(server_uuid);
        self.server_uuid = Uuid::parse_str(&uuid)?;
        Ok(())
    }

    pub async fn server_key(&self) -> Vec<u8> {
        if let Some(server_key) = Self::get_server_key(&self.server_uuid).await {
            server_key
        } else {
            Vec::new()
        }
    }

    pub async fn parse_message(&mut self, bytes: &[u8]) -> Result<Option<Message>, String> {
        let message = Message::from_bytes(bytes, &self.server_key().await)?;

        if matches!(message.data, Data::Pong) {
            self.pong();
            Ok(None)
        } else {
            Ok(Some(message))
        }
    }

    pub async fn send_message(&self, handler: &Handler, message: &mut Message) -> ESMResult {
        let message_bytes = match message.as_bytes(&self.server_key().await) {
            Ok(bytes) => bytes,
            Err(error) => return Err(error),
        };

        self.send_request(
            handler,
            ClientRequest {
                request_type: "m".into(),
                content: message_bytes,
            },
        )?;

        if matches!(message.data, Data::Ping) {
            trace!(
                "[send_message] {} - {} - {} - {:?}/{:?}",
                self.host(),
                self.server_uuid,
                message.id,
                message.message_type,
                message.data,
            );
        } else {
            info!(
                "[send_message] {} - {} - {} - {:?}/{:?}",
                self.host(),
                self.server_uuid,
                message.id,
                message.message_type,
                message.data,
            );
        }

        Ok(())
    }

    pub fn disconnect(&self, handler: &Handler) {
        info!("[disconnect] {} - {}", self.host(), self.server_uuid);
        handler.network().remove(self.resource_id);
    }

    pub async fn ping(&mut self, handler: &Handler) -> ESMResult {
        self.pong_received = false;

        self.send_message(handler, &mut Message::new().set_data(Data::Ping))
            .await
    }

    pub fn pong(&mut self) {
        self.last_checked_at = Utc::now();
        self.pong_received = true;
    }

    pub fn request_identity(&self, handler: &Handler) -> ESMResult {
        self.send_request(
            handler,
            ClientRequest {
                request_type: "id".into(),
                content: vec![],
            },
        )
    }

    pub fn request_init(&self, handler: &Handler) -> ESMResult {
        self.send_request(
            handler,
            ClientRequest {
                request_type: "i".into(),
                content: vec![],
            },
        )
    }

    fn send_request(&self, handler: &Handler, request: ClientRequest) -> ESMResult {
        let bytes = match serde_json::to_vec(&request) {
            Ok(b) => b,
            Err(e) => return Err(format!("{e}")),
        };

        match handler.network().send(self.endpoint, &bytes) {
            SendStatus::Sent => Ok(()),
            SendStatus::MaxPacketSizeExceeded => Err(format!(
                "[send] {} - {} - Cannot send - Message is too large. Size: {} bytes. {bytes:?}",
                self.host(),
                self.server_uuid,
                bytes.len()
            )),
            s => Err(format!(
                "[send] {} - {} - Cannot send - {s:?}. {bytes:?}",
                self.host(),
                self.server_uuid,
            )),
        }
    }
}
