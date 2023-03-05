use crate::*;

use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};

lazy_static! {
    /// Handles sending messages to the Bot and the A3 server
    pub static ref ROUTER: Arc<Router> = Arc::new(Router::new());
}

pub struct Router {
    server_channel: UnboundedSender<ServerRequest>,
    bot_channel: UnboundedSender<BotRequest>,
}

impl Router {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
        let (server_channel, server_receiver) = unbounded_channel::<ServerRequest>();
        let (bot_channel, bot_receiver) = unbounded_channel::<BotRequest>();

        crate::TOKIO_RUNTIME.block_on(async move {
            crate::bot::initialize(bot_receiver).await;
            crate::server::initialize(server_receiver).await;
        });

        info!("[router] ✅");

        Router {
            server_channel,
            bot_channel,
        }
    }

    pub fn route_to_server(&self, request: ServerRequest) -> ESMResult {
        match self.server_channel.send(request) {
            Ok(_) => Ok(()),
            Err(e) => Err(e.to_string()),
        }
    }

    pub fn route_to_bot(&self, request: BotRequest) -> ESMResult {
        match self.bot_channel.send(request) {
            Ok(_) => Ok(()),
            Err(e) => Err(e.to_string()),
        }
    }
}
