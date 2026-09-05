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
    decode_territory_ids(&mut message.data).await?;

    // Now process the message
    send_to_arma(message).await?;

    Ok(None)
}

// Territory IDs leave the extension encoded, so one coming back has to be resolved before SQF can match it against an
// ExileDatabaseID. They do not always sit at the top of the payload either: a reward package carries one per vehicle,
// nested inside an array. Each decoded ID is written beside its encoded one as `territory_database_id`, which is the
// key every command's SQF already reads.
async fn decode_territory_ids(data: &mut Data) -> ESMResult {
    let mut encoded_ids: HashSet<String> = HashSet::new();
    collect_territory_ids(data, &mut encoded_ids)?;

    if encoded_ids.is_empty() {
        return Ok(());
    }

    // Decoding costs a database round trip, so an ID is resolved once no matter how many times it appears. Several
    // vehicles bound for the same virtual garage is the normal case, not the exception.
    let mut decoded_ids: HashMap<String, u64> = HashMap::new();
    for encoded_id in encoded_ids {
        let database_id = DATABASE.decode_territory_id(&encoded_id).await?;
        debug!("[decode_territory_ids] Resolved {encoded_id} into {database_id}");

        decoded_ids.insert(encoded_id, database_id);
    }

    insert_database_ids(data, &decoded_ids);

    Ok(())
}

// A `territory_id` is always the encoded string the extension handed out. Anything else means the bot built a bad
// payload, and saying so here beats SQF reporting a territory that does not exist.
fn encoded_territory_id(value: Option<&JSONValue>) -> Result<Option<String>, Error> {
    let Some(value) = value else {
        return Ok(None);
    };

    let Some(id) = value.as_str() else {
        return Err(format!("[decode_territory_ids] Invalid territory ID: {value:?}").into());
    };

    Ok(Some(id.to_owned()))
}

fn collect_territory_ids(data: &Data, encoded_ids: &mut HashSet<String>) -> ESMResult {
    if let Some(id) = encoded_territory_id(data.get("territory_id"))? {
        encoded_ids.insert(id);
    }

    for value in data.values() {
        collect_nested_territory_ids(value, encoded_ids)?;
    }

    Ok(())
}

fn collect_nested_territory_ids(value: &JSONValue, encoded_ids: &mut HashSet<String>) -> ESMResult {
    match value {
        JSONValue::Object(object) => {
            if let Some(id) = encoded_territory_id(object.get("territory_id"))? {
                encoded_ids.insert(id);
            }

            for nested in object.values() {
                collect_nested_territory_ids(nested, encoded_ids)?;
            }
        }
        JSONValue::Array(entries) => {
            for entry in entries {
                collect_nested_territory_ids(entry, encoded_ids)?;
            }
        }
        _ => {}
    }

    Ok(())
}

fn insert_database_ids(data: &mut Data, decoded_ids: &HashMap<String, u64>) {
    let database_id = data
        .get("territory_id")
        .and_then(|value| value.as_str())
        .and_then(|id| decoded_ids.get(id))
        .copied();

    if let Some(database_id) = database_id {
        data.insert("territory_database_id".to_owned(), json!(database_id));
    }

    for value in data.values_mut() {
        insert_nested_database_ids(value, decoded_ids);
    }
}

fn insert_nested_database_ids(value: &mut JSONValue, decoded_ids: &HashMap<String, u64>) {
    match value {
        JSONValue::Object(object) => {
            let database_id = object
                .get("territory_id")
                .and_then(|value| value.as_str())
                .and_then(|id| decoded_ids.get(id))
                .copied();

            if let Some(database_id) = database_id {
                object.insert("territory_database_id".to_owned(), json!(database_id));
            }

            for nested in object.values_mut() {
                insert_nested_database_ids(nested, decoded_ids);
            }
        }
        JSONValue::Array(entries) => {
            for entry in entries {
                insert_nested_database_ids(entry, decoded_ids);
            }
        }
        _ => {}
    }
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

#[cfg(test)]
mod tests {
    use super::*;

    // The shape a reward package arrives in: one territory per vehicle, nested two levels down
    fn reward_payload() -> Data {
        HashMap::from([
            ("items".to_owned(), json!({"Exile_Item_Cheathas": 2})),
            (
                "vehicles".to_owned(),
                json!([
                    {"class_name": "Exile_Car_Hatchback_Rusty1", "spawn_location": "nearby"},
                    {"class_name": "Exile_Car_Hunter", "spawn_location": "virtual_garage", "territory_id": "a3f9k"},
                    {"class_name": "Exile_Car_Ifrit", "spawn_location": "virtual_garage", "territory_id": "b7c2m"},
                ]),
            ),
        ])
    }

    fn collect(data: &Data) -> Result<HashSet<String>, Error> {
        let mut encoded_ids = HashSet::new();
        collect_territory_ids(data, &mut encoded_ids)?;

        Ok(encoded_ids)
    }

    #[test]
    fn it_collects_a_top_level_territory_id() {
        let data = HashMap::from([("territory_id".to_owned(), json!("a3f9k"))]);

        assert_eq!(collect(&data).unwrap(), HashSet::from(["a3f9k".to_owned()]));
    }

    #[test]
    fn it_collects_territory_ids_nested_in_an_array() {
        assert_eq!(
            collect(&reward_payload()).unwrap(),
            HashSet::from(["a3f9k".to_owned(), "b7c2m".to_owned()])
        );
    }

    #[test]
    fn it_collects_a_repeated_territory_id_once() {
        let data = HashMap::from([
            ("territory_id".to_owned(), json!("a3f9k")),
            ("vehicles".to_owned(), json!([{"territory_id": "a3f9k"}, {"territory_id": "a3f9k"}])),
        ]);

        assert_eq!(collect(&data).unwrap(), HashSet::from(["a3f9k".to_owned()]));
    }

    #[test]
    fn it_collects_nothing_when_the_payload_has_no_territory() {
        let data = HashMap::from([("locker".to_owned(), json!(5_000))]);

        assert!(collect(&data).unwrap().is_empty());
    }

    #[test]
    fn it_rejects_a_territory_id_that_is_not_a_string() {
        let data = HashMap::from([("vehicles".to_owned(), json!([{"territory_id": 12}]))]);

        assert!(collect(&data).is_err());
    }

    #[test]
    fn it_inserts_a_database_id_beside_every_encoded_one() {
        let mut data = reward_payload();
        let decoded_ids = HashMap::from([("a3f9k".to_owned(), 42), ("b7c2m".to_owned(), 7)]);

        insert_database_ids(&mut data, &decoded_ids);

        let vehicles = data["vehicles"].as_array().unwrap();

        // The vehicle spawning nearby was never given a territory and must not gain one
        assert!(vehicles[0].get("territory_database_id").is_none());

        assert_eq!(vehicles[1]["territory_database_id"], json!(42));
        assert_eq!(vehicles[2]["territory_database_id"], json!(7));

        // The encoded ID stays put. Only SQF cares which one it reads
        assert_eq!(vehicles[1]["territory_id"], json!("a3f9k"));
    }

    #[test]
    fn it_inserts_a_database_id_at_the_top_level() {
        let mut data = HashMap::from([("territory_id".to_owned(), json!("a3f9k"))]);

        insert_database_ids(&mut data, &HashMap::from([("a3f9k".to_owned(), 42)]));

        assert_eq!(data["territory_database_id"], json!(42));
    }

    #[test]
    fn it_leaves_an_undecoded_territory_id_alone() {
        let mut data = HashMap::from([("territory_id".to_owned(), json!("a3f9k"))]);

        insert_database_ids(&mut data, &HashMap::new());

        assert!(data.get("territory_database_id").is_none());
    }
}
