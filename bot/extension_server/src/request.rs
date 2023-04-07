use esm_message::Message;
use message_io::network::Endpoint;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::ESMResult;

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum BotRequest {
    // esm_bot -> server.rs
    ServerRequest(ServerRequest),

    // bot.rs -> esm_bot
    Ping,

    // esm_bot -> bot.rs
    Pong,

    // esm_bot -> server.rs -> esm_arma
    SendToClient {
        server_uuid: Uuid,
        message: Box<Message>,
    },

    // extension_server -> esm_bot
    #[serde(rename(serialize = "inbound"))]
    Send {
        server_uuid: Option<Uuid>,
        message: Box<Message>,
    },

    // server.rs -> esm_bot
    Disconnected(Option<Uuid>),
}

impl BotRequest {
    pub fn server_request(request: ServerRequest) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::ServerRequest(request))
    }

    pub fn ping() -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Ping)
    }

    pub fn pong() -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Pong)
    }

    pub fn send_to_client(server_uuid: Uuid, message: Message) -> ESMResult {
        ServerRequest::send(server_uuid, message)
    }

    pub fn send(message: Message, server_uuid: Option<Uuid>) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Send {
            server_uuid,
            message: Box::new(message),
        })
    }

    pub fn disconnected(server_uuid: Uuid) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Disconnected(Some(server_uuid)))
    }
}

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ServerRequest {
    // esm_bot -> server.rs
    Disconnect(Option<Uuid>),

    // esm_bot -> server.rs
    Resume,

    // esm_bot -> server.rs
    Pause,

    // esm_bot -> server.rs -> esm_arma
    Send {
        server_uuid: Uuid,
        message: Box<Message>,
    },

    // server.rs -> server.rs
    #[serde(skip)]
    AliveCheck,

    // server.rs -> server.rs
    #[serde(skip)]
    DisconnectEndpoint(Endpoint),

    // server.rs -> server.rs
    #[serde(skip)]
    OnConnect(Endpoint),

    // server.rs -> server.rs
    #[serde(skip)]
    OnMessage {
        endpoint: Endpoint,
        bytes: Vec<u8>,
    },

    // server.rs -> server.rs
    #[serde(skip)]
    OnDisconnect(Endpoint),
}

impl ServerRequest {
    pub fn disconnect(server_id: Option<Uuid>) -> ESMResult {
        crate::ROUTER.route_to_server(Self::Disconnect(server_id))
    }

    pub fn resume() -> ESMResult {
        crate::ROUTER.route_to_server(Self::Resume)
    }

    pub fn pause() -> ESMResult {
        crate::ROUTER.route_to_server(Self::Pause)
    }

    pub fn send(server_uuid: Uuid, message: Message) -> ESMResult {
        crate::ROUTER.route_to_server(Self::Send {
            server_uuid,
            message: Box::new(message),
        })
    }

    pub fn alive_check() -> ESMResult {
        crate::ROUTER.route_to_server(Self::AliveCheck)
    }

    pub fn disconnect_endpoint(endpoint: Endpoint) -> ESMResult {
        crate::ROUTER.route_to_server(Self::DisconnectEndpoint(endpoint))
    }

    pub fn on_connect(endpoint: Endpoint) -> ESMResult {
        crate::ROUTER.route_to_server(Self::OnConnect(endpoint))
    }

    pub fn on_message(endpoint: Endpoint, bytes: &[u8]) -> ESMResult {
        crate::ROUTER.route_to_server(Self::OnMessage {
            endpoint,
            bytes: bytes.into(),
        })
    }

    pub fn on_disconnect(endpoint: Endpoint) -> ESMResult {
        crate::ROUTER.route_to_server(Self::OnDisconnect(endpoint))
    }
}

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug)]
pub struct ClientRequest {
    #[serde(rename = "t")]
    pub request_type: String,

    #[serde(rename = "c", default, skip_serializing_if = "Vec::is_empty")]
    pub content: Vec<u8>,
}
