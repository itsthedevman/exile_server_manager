use crate::database::Database;
use crate::*;

use crate::log_search;
use arma_rs::{Context, IntoArma};
use database::QueryError;
use std::{
    collections::HashSet,
    iter::FromIterator,
    sync::{atomic::AtomicU64, Mutex as SyncMutex},
};
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    pub static ref DATABASE: Database = Database::new();
    static ref TERRITORY_ADMINS: Arc<SyncMutex<HashSet<String>>> =
        Arc::new(SyncMutex::new(HashSet::new()));
    static ref CALLBACK: Arc<SyncMutex<Option<Context>>> =
        Arc::new(SyncMutex::new(None));
    pub static ref MAX_PAYMENT_COUNT: AtomicU64 = AtomicU64::new(0);
}

pub fn is_territory_admin(steam_uid: &str) -> bool {
    lock!(TERRITORY_ADMINS).contains(&steam_uid.to_string())
}

pub async fn initialize(receiver: UnboundedReceiver<ArmaRequest>) {
    trace!("[initialize] Loading threads");
    request_thread(receiver).await;
}

async fn request_thread(mut receiver: UnboundedReceiver<ArmaRequest>) {
    tokio::spawn(async move {
        loop {
            let Some(request) = receiver.recv().await else {
                continue;
            };

            trace!("[routing_thread] Processing request: {request}");

            let result: Option<Message> = match request {
                ArmaRequest::Query(message) => execute("query", *message).await,
                ArmaRequest::Method { name, message } => {
                    execute(name.as_str(), *message).await
                }
                ArmaRequest::Initialize(context) => {
                    *lock!(CALLBACK) = Some(context);
                    continue;
                }
                ArmaRequest::Search(message) => execute("search", *message).await,
            };

            // If a message is returned, send it back
            if let Some(m) = result {
                if let Err(e) =
                    crate::ROUTER.route_to_bot(BotRequest::Send(Box::new(m)))
                {
                    error!("[request_thread] ❌ {e}");
                };
            }
        }
    });
}

async fn execute(name: &str, message: Message) -> Option<Message> {
    let message_id = message.id;

    trace!("[execute] Executing {name} for message id:{message_id}");

    let result = match name {
        "query" => database_query(message).await,
        "search" => file_search(message).await,
        "post_initialization" => post_initialization(message).await,
        "call_function" => call_arma_function(message).await,
        n => Err(format!(
            "[execute] Cannot process - Arma does not respond to method {n}"
        )
        .into()),
    };

    match result {
        Ok(m) => m,
        Err(e) => {
            let message = Message::new()
                .set_id(message_id)
                .add_error(e.error_type, e.error_content);

            Some(message)
        }
    }
}

async fn send_to_arma(message: Message) -> ESMResult {
    let function_name = message.data.require_str("function_name", "send_to_arma")?;

    if function_name.is_empty() {
        return Err("[send_to_arma] Dropping message since it does not have a registered SQF function".into());
    }

    match function_name {
        "ESMs_command_pay" => {
            check_payment_counter(&message).await?;
        }
        _ => {}
    }

    info!("[send_to_arma] {} - calling {}", message.id, function_name);

    let message = vec![
        vec!["id".to_arma(), message.id.to_arma()],
        vec!["data".to_arma(), message.data.to_arma()],
        vec!["metadata".to_arma(), message.metadata.to_arma()],
    ];

    match &*lock!(CALLBACK) {
        Some(ctx) => {
            let _ = ctx.callback_data("exile_server_manager", &function_name, Some(message));
            Ok(())
        }
        None => Err(
            "[send_to_arma] Cannot send - We are not connected to the Arma server at the moment"
                .into(),
        ),
    }
}

async fn post_initialization(mut message: Message) -> MessageResult {
    info!("[post_init] Validating...");

    let data = &mut message.data;

    data.insert(
        "build_number".to_owned(),
        json!(std::include_str!("../.build-sha").to_string()),
    );

    data.insert(
        "version".to_owned(),
        json!(env!("CARGO_PKG_VERSION").to_string()),
    );

    data.insert("extdb_version".to_owned(), json!(DATABASE.extdb_version));

    info!("[post_init] Caching data...");

    // Store the territory admins
    let territory_admin_uids: Vec<String> = data
        .require_array("territory_admin_uids", "post_init")?
        .iter()
        .filter_map(serde_json::Value::as_str)
        .map(String::from)
        .collect();

    *lock!(TERRITORY_ADMINS) =
        HashSet::from_iter(territory_admin_uids.iter().cloned());

    // Cache the max payment count
    // Clamped rather than rejected. A count below zero is a setting nobody configured, which is what zero
    // already means here, and failing post_init over it would cost the server its whole connection.
    let payment_count = data.require_i64("max_payment_count", "post_init")?;
    MAX_PAYMENT_COUNT.store(payment_count.max(0) as u64, Ordering::SeqCst);

    info!("[post_init] Updating Arma global variables...");

    send_to_arma(message).await?;

    info!("[post_init] ✅ Connection established");

    crate::READY.store(true, Ordering::SeqCst);

    Ok(None)
}

async fn call_arma_function(mut message: Message) -> MessageResult {
    // If the data has a territory_id, check it against the database
    if message.data.contains_key("territory_id") {
        decode_territory_id(&mut message).await?;
    }

    // Now process the message
    send_to_arma(message).await?;

    Ok(None)
}

async fn decode_territory_id(message: &mut Message) -> ESMResult {
    let Some(territory_id) = message.data.get_mut("territory_id") else {
        return Err("[decode_territory_id] Failed to gain mut access to data object on Message. This is a bug".into());
    };

    let Some(id) = territory_id.as_str() else {
        return Err(format!(
            "[decode_territory_id] Invalid territory ID: {:?}",
            territory_id
        )
        .into());
    };

    let decoded_id = DATABASE.decode_territory_id(id).await?;
    debug!("[decode_territory_id] Resolved {territory_id} into {decoded_id}");

    // Add the decoded database ID to the data object
    message
        .data
        .insert("territory_database_id".to_owned(), json!(decoded_id));

    Ok(())
}

async fn file_search(message: Message) -> MessageResult {
    let search = message
        .data
        .get("search")
        .ok_or::<String>("[file_search] ❌ Missing key `search` argument".into())?;

    let Some(search) = search.as_str() else {
        return Err(format!(
            "[file_search] ❌ Failed to convert {search:?} to string"
        )
        .into());
    };

    info!(
        "[file_search] {} - searching files for \"{}\"",
        message.id, search
    );

    match log_search::search_files(&search).await {
        Ok(results) => {
            let message = message
                .set_type(Type::Ack)
                .set_data(Data::from([("results".to_owned(), json!(results))]));

            Ok(Some(message))
        }
        Err(e) => Err(e.into()),
    }
}

async fn database_query(message: Message) -> MessageResult {
    let mut arguments = message.data;

    let Some(name) = arguments.remove("query_function_name") else {
        return Err(
            "Missing \"query_function_name\" attribute for database query".into(),
        );
    };

    info!(
        "[database_query] {} - executing query {} with {} arguments",
        message.id,
        name,
        arguments.len()
    );

    let result = match name.as_str().unwrap_or_default() {
        "update_xm8_notification_state" => {
            DATABASE.update_xm8_notification_state(arguments).await
        }
        // Any queries that use HashMap<String, String> as arguments
        name => {
            let arguments = arguments
                .into_iter()
                .map(|(k, v)| {
                    (
                        k,
                        v.as_str()
                            .map(ToString::to_string)
                            .unwrap_or_else(|| v.to_string()),
                    )
                })
                .collect();

            match name {
                "all_territories" => {
                    DATABASE.command_all_territories(arguments).await
                }
                "me" | "player_info" => {
                    DATABASE.command_player_info(arguments).await
                }
                "player_territories" => {
                    DATABASE.command_player_territories(arguments).await
                }
                "players_list" => DATABASE.command_players_list(arguments).await,
                "reset_all" => DATABASE.command_reset_all(arguments).await,
                "reset_player" => DATABASE.command_reset_player(arguments).await,
                "restore" => DATABASE.command_restore(arguments).await,
                "reward_territories" => {
                    DATABASE.command_reward_territories(arguments).await
                }
                "set_id" => DATABASE.command_set_id(arguments).await,
                "territory_info" => DATABASE.command_territory_info(arguments).await,
                _ => Err(QueryError::System(format!(
                    "Unexpected query \"{}\" with arguments {:?}",
                    name, arguments
                ))),
            }
        }
    };

    match result {
        Ok(results) => Ok(Some(
            Message::new()
                .set_id(message.id)
                .set_type(Type::Query)
                .set_data(Data::from([("results".to_owned(), json!(results))])),
        )),
        Err(e) => match e {
            QueryError::System(e) => {
                error!(
                    "[database_query#{name}] ❌ {e}",
                    // The quotes bothered me.
                    name = name.as_str().unwrap_or("INVALID_QUERY_NAME")
                );
                Err(Error::code("error"))
            }
            QueryError::User(e) => Err(Error::message(e)),
            QueryError::Code(e) => Err(Error::code(e)),
        },
    }
}

async fn check_payment_counter(message: &Message) -> ESMResult {
    let max_payment_count = MAX_PAYMENT_COUNT.load(Ordering::SeqCst);

    if max_payment_count == 0 {
        return Ok(());
    }

    let territory_id = message
        .data
        .require_u64("territory_database_id", "check_payment_counter")?;

    let payment_counter =
        DATABASE.get_territory_payment_counter(territory_id).await?;

    if payment_counter < max_payment_count {
        return Ok(());
    }

    Err(Error::code("max_payment_count"))
}
