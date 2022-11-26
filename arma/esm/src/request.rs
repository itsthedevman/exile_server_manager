use arma_rs::Context;
use esm_message::{Init, Message};
use serde::{Deserialize, Serialize};

use crate::ESMResult;

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
            ArmaRequest::Query(m) => f.debug_tuple("ArmaRequest::Query").field(m).finish(),
            ArmaRequest::Method { name, message } => f
                .debug_struct("ArmaRequest::Method")
                .field("name", name)
                .field("message", message)
                .finish(),
            ArmaRequest::Initialize(_) => f.debug_tuple("ArmaRequest::Initialize").finish(),
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

#[derive(Serialize, Deserialize, Debug)]
pub struct ServerRequest {
    #[serde(rename = "t")]
    pub request_type: String,

    #[serde(rename = "c", default, skip_serializing_if = "Vec::is_empty")]
    pub content: Vec<u8>,
}
