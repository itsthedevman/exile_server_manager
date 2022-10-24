use crate::*;

use esm_message::{Init, Message};
use std::time::Duration;
use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};

pub struct Router {
    arma_channel: UnboundedSender<RoutingCommand>,
    bot_channel: UnboundedSender<RoutingCommand>,
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
        self.route_internal(
            "arma",
            RoutingCommand::Method {
                name: name.to_string(),
                message: Box::new(message),
            },
        )
    }

    pub fn route_to_bot(&self, message: Message) -> ESMResult {
        self.route_internal(
            "bot",
            RoutingCommand::Send {
                message: Box::new(message),
                delay: None,
            },
        )
    }

    pub fn route_internal(&self, destination: &str, command: RoutingCommand) -> ESMResult {
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

pub enum RoutingCommand {
    // Client
    Connect,
    Send {
        message: Box<Message>,
        delay: Option<Duration>,
    },
    ClientInitialize {
        init: Init,
    },

    // Arma
    Query(Box<Message>),
    Method {
        name: String,
        message: Box<Message>,
    },
    ArmaInitialize {
        context: Context,
    },
}

impl std::fmt::Display for RoutingCommand {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            RoutingCommand::Connect => f.debug_struct("RoutingCommand::Connect").finish(),
            RoutingCommand::Send { message, delay } => f
                .debug_struct("RoutingCommand::Send")
                .field("message", message)
                .field("delay", delay)
                .finish(),
            RoutingCommand::ClientInitialize { init } => f
                .debug_struct("RoutingCommand::ClientInitialize")
                .field("init", init)
                .finish(),
            RoutingCommand::Query(message) => f
                .debug_tuple("RoutingCommand::Query")
                .field(message)
                .finish(),
            RoutingCommand::Method { name, message } => f
                .debug_struct("RoutingCommand::Method")
                .field("name", name)
                .field("message", message)
                .finish(),
            RoutingCommand::ArmaInitialize { context: _ } => {
                f.debug_struct("RoutingCommand::ArmaInitialize").finish()
            }
        }
    }
}
