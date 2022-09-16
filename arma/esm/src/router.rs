use crate::*;

use arma_rs::Context;
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
        let (client_channel, client_receiver) = unbounded_channel();

        crate::TOKIO_RUNTIME.block_on(async {
            crate::bot::initialize(client_receiver).await;
            crate::arma::initialize(arma_receiver).await;
        });

        Router {
            arma_channel,
            bot_channel: client_channel,
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
        match destination {
            "bot" => match self.bot_channel.send(command) {
                Ok(_) => Ok(()),
                Err(e) => Err(format!("Failed to route {}", e).into()),
            },
            "arma" => match self.arma_channel.send(command) {
                Ok(_) => Ok(()),
                Err(e) => Err(format!("Failed to route {}", e).into()),
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
            RoutingCommand::ArmaInitialize { context: _ } => {
                write!(f, "RoutingCommand::ArmaInitialize")
            }
            c => write!(f, "{}", c),
        }
    }
}
