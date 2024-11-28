use crate::*;
use arma_rs::Context;
use serde::{Deserialize, Serialize};
use serde_repr::{Deserialize_repr, Serialize_repr};
use uuid::Uuid;

use crate::ESMResult;
use crate::Init;

pub enum ArmaRequest {
    Query(Box<Message>),
    Method { name: String, message: Box<Message> },
    Initialize(Context),
}

impl ArmaRequest {
    pub fn initialize(context: Context) -> ESMResult {
        crate::ROUTER.route_to_arma(Self::Initialize(context))
    }

    pub fn call(name: &str, message: Message) -> ESMResult {
        crate::ROUTER.route_to_arma(Self::Method {
            name: name.to_string(),
            message: Box::new(message),
        })
    }

    pub fn query(message: Message) -> ESMResult {
        crate::ROUTER.route_to_arma(Self::Query(Box::new(message)))
    }
}

impl std::fmt::Display for ArmaRequest {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ArmaRequest::Query(m) => {
                f.debug_tuple("ArmaRequest::Query").field(m).finish()
            }
            ArmaRequest::Method { name, message } => f
                .debug_struct("ArmaRequest::Method")
                .field("name", name)
                .field("message", message)
                .finish(),
            ArmaRequest::Initialize(_) => {
                f.debug_tuple("ArmaRequest::Initialize").finish()
            }
        }
    }
}

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////

pub enum BotRequest {
    Connect,
    Send(Box<Message>),
    Initialize(Init),
}

impl BotRequest {
    pub fn connect() -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Connect)
    }

    pub fn initialize(init: Init) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Initialize(init))
    }

    pub fn send(message: Message) -> ESMResult {
        crate::ROUTER.route_to_bot(Self::Send(Box::new(message)))
    }
}

impl std::fmt::Display for BotRequest {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            BotRequest::Send(m) => f.debug_tuple("BotRequest::Send").field(m).finish(),
            BotRequest::Connect => f.debug_tuple("BotRequest::Connect").finish(),
            BotRequest::Initialize(_) => f.debug_tuple("BotRequest::Initialize").finish(),
        }
    }
}

///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////
#[derive(Serialize_repr, Deserialize_repr, Debug)]
#[repr(u8)]
// repr turns the enums to u8
pub enum RequestType {
    Noop = 0,
    Error = 1,
    Heartbeat = 2,
    Identification = 3,
    Initialize = 4,
    Handshake = 5,
    Message = 6,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Request {
    #[serde(rename = "i")]
    pub id: Uuid,

    #[serde(rename = "t")]
    pub request_type: RequestType,

    #[serde(rename = "c", default, skip_serializing_if = "Vec::is_empty")]
    pub value: Vec<u8>,
}

impl Request {
    pub fn new() -> Self {
        Self {
            id: Uuid::new_v4(),
            request_type: RequestType::Noop,
            value: vec![],
        }
    }

    pub fn set_id(mut self, id: Uuid) -> Self {
        self.id = id;
        self
    }

    pub fn set_type(mut self, request_type: RequestType) -> Self {
        self.request_type = request_type;
        self
    }

    pub fn set_value(mut self, content: Vec<u8>) -> Self {
        self.value = content;
        self
    }
}
