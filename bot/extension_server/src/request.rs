use esm_message::Message;
use message_io::network::Endpoint;
use serde::{Deserialize, Serialize};

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
        server_id: Vec<u8>,
        message: Box<Message>,
    },

    // extension_server -> esm_bot
    #[serde(rename(serialize = "inbound"))]
    Send(Box<Message>),

    // server.rs -> esm_bot
    Disconnected(Vec<u8>),
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

    pub fn send_to_client(server_id: &[u8], message: Message) -> ESMResult {
        ServerRequest::send(server_id, message)
    }

    pub fn send(message: Message) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Send(Box::new(message)))
    }

    pub fn disconnected(server_id: &[u8]) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Disconnected(server_id.into()))
    }
}

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

#[derive(Serialize, Deserialize, Debug)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum ServerRequest {
    // esm_bot -> server.rs
    Disconnect(Option<Vec<u8>>),

    // esm_bot -> server.rs
    Resume,

    // esm_bot -> server.rs
    Pause,

    // esm_bot -> server.rs -> esm_arma
    Send {
        server_id: Vec<u8>,
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
    pub fn disconnect(server_id: Option<Vec<u8>>) -> ESMResult {
        crate::ROUTER.route_to_server(Self::Disconnect(server_id))
    }

    pub fn resume() -> ESMResult {
        crate::ROUTER.route_to_server(Self::Resume)
    }

    pub fn pause() -> ESMResult {
        crate::ROUTER.route_to_server(Self::Pause)
    }

    pub fn send(server_id: &[u8], message: Message) -> ESMResult {
        crate::ROUTER.route_to_server(Self::Send {
            server_id: server_id.into(),
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
