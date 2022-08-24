use crate::*;
use tokio::time::{sleep, Duration};

lazy_static! {
    /// The actual connection to the bot - Used internally
    pub static ref CLIENT: Arc<Client> = Arc::new(Client::new());
}

pub struct ConnectionManager {
    connected: Arc<AtomicBool>,
    pong_received: Arc<AtomicBool>,
}

impl Default for ConnectionManager {
    fn default() -> Self {
        ConnectionManager {
            connected: Arc::new(AtomicBool::new(false)),
            pong_received: Arc::new(AtomicBool::new(false)),
        }
    }
}

impl ConnectionManager {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn connect(&self) {
        let reconnection_counter = AtomicUsize::new(0);
        let connected = self.connected.clone();

        tokio::spawn(async move {
            loop {
                if let Err(e) = CLIENT.connect().await {
                    error!("[connection_manager#connect] Failed to connect {e}");
                    sleep(Duration::from_secs(1)).await;
                    continue;
                };

                while connected.load(Ordering::SeqCst) {
                    reconnection_counter.store(0, Ordering::SeqCst);
                    sleep(Duration::from_secs(1)).await;
                }

                // Get the current reconnection count and calculate the wait time
                let current_count = reconnection_counter.load(Ordering::SeqCst);
                let time_to_wait = match crate::CONFIG.env {
                    Env::Test => 1,
                    Env::Development => 3,
                    _ => current_count * 15,
                };

                let time_to_wait = Duration::from_secs(time_to_wait as u64);
                warn!(
                    "[connection_manager] Lost connection to esm_bot - Attempting reconnect in {:?}",
                    time_to_wait
                );

                // Sleep a max of 5 minutes
                if current_count <= 20 {
                    // Increase the reconnect counter by 1
                    reconnection_counter.fetch_add(1, Ordering::SeqCst);
                }

                sleep(time_to_wait).await;
            }
        });

        self.alive_check().await;
    }

    async fn alive_check(&self) {
        let pong_received = self.pong_received.clone();
        let connected = self.connected.clone();

        tokio::spawn(async move {
            loop {
                sleep(Duration::from_millis(500)).await;
                if !pong_received.load(Ordering::SeqCst) {
                    continue;
                }

                let message = Message::new(Type::Ping);
                if let Err(e) = crate::BOT.send(message).await {
                    error!("[connection_manager#alive_check] Failed to send ping - {e}");
                    continue;
                };

                pong_received.store(false, Ordering::SeqCst);

                // Give the bot up to 200ms to reply before considering it "offline"
                let mut currently_connected = false;
                for _ in 0..200 {
                    if pong_received.load(Ordering::SeqCst) {
                        currently_connected = true;
                        break;
                    }

                    sleep(Duration::from_millis(1)).await;
                }

                // Only write and log if the status has changed
                let previously_connected = connected.load(Ordering::SeqCst);
                if currently_connected == previously_connected {
                    continue;
                }

                connected.store(currently_connected, Ordering::SeqCst);

                if currently_connected {
                    info!("[connection_manager#alive_check] - Connected");
                } else {
                    warn!("[connection_manager#alive_check] - Disconnected");
                }
            }
        });
    }
}
