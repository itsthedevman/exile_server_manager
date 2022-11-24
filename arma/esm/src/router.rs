use crate::*;

use tokio::sync::mpsc::{unbounded_channel, UnboundedSender};

lazy_static! {
    /// Handles sending messages to the Bot and the A3 server
    pub static ref ROUTER: Arc<Router> = Arc::new(Router::new());
}

pub struct Router {
    arma_channel: UnboundedSender<ArmaRequest>,
    bot_channel: UnboundedSender<BotRequest>,
}

impl Router {
    #[allow(clippy::new_without_default)]
    pub fn new() -> Self {
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

    pub fn route_to_arma(&self, request: ArmaRequest) -> ESMResult {
        match self.arma_channel.send(request) {
            Ok(_) => {
                trace!("[router#route_to_arma] Sent");
                Ok(())
            }
            Err(e) => Err(format!("Failed to route. Reason: {}", e).into()),
        }
    }

    pub fn route_to_bot(&self, request: BotRequest) -> ESMResult {
        match self.bot_channel.send(request) {
            Ok(_) => {
                trace!("[router#route_to_bot] Sent");
                Ok(())
            }
            Err(e) => Err(format!("Failed to route. Reason: {}", e).into()),
        }
    }
}
