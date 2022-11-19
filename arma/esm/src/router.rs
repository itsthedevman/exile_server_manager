use crate::*;

use esm_message::{Init, Message};
use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};

pub struct Router {
    arma_channel: UnboundedSender<RoutingRequest>,
    bot_channel: UnboundedSender<RoutingRequest>,
}

impl Default for Router {
    fn default() -> Self {
        let (arma_channel, arma_receiver) = unbounded_channel();
        let (bot_channel, bot_receiver) = unbounded_channel();

        crate::TOKIO_RUNTIME.block_on(async move {
            crate::bot::initialize(bot_receiver).await;
            crate::arma::initialize(arma_receiver).await;
        });

        Router {
            arma_channel,
            bot_channel,
        }
    }
}

impl Router {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn route_to_arma(&self, name: &str, message: Message) -> ESMResult {
        self.route(
            "arma",
            RoutingRequest::Method {
                name: name.to_string(),
                message: Box::new(message),
            },
        )
    }

    pub fn route_to_bot(&self, message: Message) -> ESMResult {
        self.route("bot", RoutingRequest::Send(Box::new(message)))
    }

    pub fn route(&self, destination: &str, command: RoutingRequest) -> ESMResult {
        trace!("[router#route_internal] Destination: {destination} - Package: {command}");
        match destination {
            "bot" => match self.bot_channel.send(command) {
                Ok(_) => Ok(()),
                Err(e) => Err(format!("Failed to route. Reason: {}", e).into()),
            },
            "arma" => match self.arma_channel.send(command) {
                Ok(_) => Ok(()),
                Err(e) => Err(format!("Failed to route. Reason: {}", e).into()),
            },
            r => Err(format!("Invalid destination \"{r}\" provided to router").into()),
        }
    }
}

pub enum RoutingRequest {
    // Client
    Connect,
    Send(Box<Message>),
    ClientInitialize { init: Init },

    // Arma
    Query(Box<Message>),
    Method { name: String, message: Box<Message> },
    ArmaInitialize { context: Context },
}

impl std::fmt::Display for RoutingRequest {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RoutingRequest::Connect => f.debug_struct("RoutingRequest::Connect").finish(),
            RoutingRequest::Send(message) => f
                .debug_tuple("RoutingRequest::Send")
                .field(message)
                .finish(),
            RoutingRequest::ClientInitialize { init } => f
                .debug_struct("RoutingRequest::ClientInitialize")
                .field("init", init)
                .finish(),
            RoutingRequest::Query(message) => f
                .debug_tuple("RoutingRequest::Query")
                .field(message)
                .finish(),
            RoutingRequest::Method { name, message } => f
                .debug_struct("RoutingRequest::Method")
                .field("name", name)
                .field("message", message)
                .finish(),
            RoutingRequest::ArmaInitialize { context: _ } => {
                f.debug_struct("RoutingRequest::ArmaInitialize").finish()
            }
        }
    }
}
