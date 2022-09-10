use crate::*;
use tokio::time::{sleep, Duration};

// lazy_static! {
//     /// The actual connection to the bot - Used internally
//     pub static ref CLIENT: Arc<Client> = Arc::new(Client::new());
// }

pub struct ConnectionManager {
    pub connected: Arc<AtomicBool>,
}

impl Default for ConnectionManager {
    fn default() -> Self {
        ConnectionManager {
            connected: Arc::new(AtomicBool::new(false)),
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
                // match CLIENT.connect() {
                //     Ok(_) => {
                //         reconnection_counter.store(0, Ordering::SeqCst);

                //         while connected.load(Ordering::SeqCst) {
                //             sleep(Duration::from_secs(1)).await;
                //         }
                //     }
                //     Err(e) => {
                //         error!("[connection_manager#connect] ❌ Failed to connect {e}");
                //     }
                // };

                // Get the current reconnection count and calculate the wait time
                let current_count = reconnection_counter.load(Ordering::SeqCst);
                let time_to_wait = match crate::CONFIG.env {
                    Env::Test => continue,
                    Env::Development => 3.0,
                    _ => (current_count * 15) as f32,
                };

                let time_to_wait = Duration::from_secs_f32(time_to_wait);
                warn!(
                    "[connection_manager] ⚠ Lost connection to esm_bot - Attempting reconnect in {:?}",
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
    }
}
