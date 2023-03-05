mod bot;
mod client;
mod client_manager;
mod macros;
mod request;
mod router;
mod server;

use lazy_static::lazy_static;
use parking_lot::Mutex;
use std::sync::{atomic::AtomicBool, Arc};
use tokio::runtime::Runtime;
use tokio::sync::Mutex as AsyncMutex;
use tokio_postgres::{Client as PsqlClient, NoTls};

pub use esm_message::*;
pub use log::{debug, error, info, trace, warn};

pub use request::*;
pub use router::ROUTER;

pub type ESMResult = Result<(), String>;

lazy_static! {
    /// Is the bot ready to receive messages?
    pub static ref BOT_CONNECTED: AtomicBool = AtomicBool::new(false);

    /// Is the server ready to receive messages?
    pub static ref SERVER_READY: AtomicBool = AtomicBool::new(false);

    /// The runtime for the asynchronous code
    pub static ref TOKIO_RUNTIME: Arc<Runtime> = Arc::new(tokio::runtime::Builder::new_multi_thread().enable_all().build().unwrap());

    /// The connection to the database
    pub static ref DATABASE: Arc<AsyncMutex<Option<PsqlClient>>> = Arc::new(AsyncMutex::new(None));
}

const REDIS_URI: &str = "redis://127.0.0.1";
const SERVER_PORT: &str = "3003";

async fn connect_to_database() -> ESMResult {
    let connection_config = format!(
        "host={host} port={port} user={username} password={password} dbname={database_name}",
        host = option_env!("POSTGRES_HOST").unwrap_or("localhost"),
        port = option_env!("POSTGRES_PORT").unwrap_or("5432"),
        username = option_env!("POSTGRES_USERNAME").unwrap_or("esm"),
        password = option_env!("POSTGRES_PASSWORD").unwrap_or("password12345"),
        database_name = option_env!("POSTGRES_DATABASE").unwrap_or("esm_development"),
    );

    let (client, connection) = match tokio_postgres::connect(&connection_config, NoTls).await {
        Ok(c) => c,
        Err(e) => {
            return Err(format!(
                "[connect_to_database] Connection error occurred - {e}"
            ))
        }
    };

    tokio::spawn(async {
        if let Err(e) = connection.await {
            error!("[connect_to_database - spawn] Connection error occurred - {e}");
        }

        // Sleep and then call again?
    });

    *await_lock!(DATABASE) = Some(client);

    Ok(())
}

fn main() {
    env_logger::builder().format_timestamp_millis().init();
    info!("[main] Starting...");

    lazy_static::initialize(&ROUTER);

    // heartbeat_thread is forever blocking
    crate::TOKIO_RUNTIME.block_on(async {
        if let Err(e) = connect_to_database().await {
            error!("{e}")
        }

        bot::heartbeat().await;
    });
}
