use crate::database::Database;
use crate::*;

use arma_rs::{Context, IntoArma};
use std::sync::Mutex as SyncMutex;
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    pub static ref DATABASE: Database = Database::new();
    static ref CALLBACK: Arc<SyncMutex<Option<Context>>> = Arc::new(SyncMutex::new(None));
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
                ArmaRequest::Method { name, message } => execute(name.as_str(), *message).await,
                ArmaRequest::Initialize(context) => {
                    *lock!(CALLBACK) = Some(context);
                    continue;
                }
            };

            // If a message is returned, send it back
            if let Some(m) = result {
                if let Err(e) = crate::ROUTER.route_to_bot(BotRequest::Send(Box::new(m))) {
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
        "post_initialization" => post_initialization(message).await,
        "call_function" => call_arma_function(message).await,
        n => Err(format!("[execute] Cannot process - Arma does not respond to method {n}").into()),
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

fn send_to_arma(message: Message) -> ESMResult {
    let Some(function_name) = message.data.get("function_name") else {
        return Err("Missing function_name attribute on message".into());
    };

    let function_name = function_name.as_str().unwrap_or("");

    if function_name.is_empty() {
        return Err(format!(
            "[send_to_arma] Dropping message with data type {:?} since it does not have a registered SQF function",
            message.data
        ).into());
    }

    info!(
        "[send_to_arma] {} - Calling {} with\ndata: {}\nmetadata: {}",
        message.id,
        function_name,
        serde_json::to_string_pretty(&message.data).unwrap_or_default(),
        serde_json::to_string_pretty(&message.metadata).unwrap_or_default()
    );

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
    info!("[post_init] Validating post initialization...");

    let data = &mut message.data;

    // Get the base path to figure out where to look for the ini
    let Some(base_ini_path) = data.get("extdb_path") else {
        return Err("Missing extdb_path attribute on message".into());
    };

    let base_ini_path = base_ini_path.as_str().unwrap_or("");
    let base_ini_path = if base_ini_path.is_empty() {
        crate::CONFIG.server_mod_name.clone()
    } else {
        base_ini_path.to_owned()
    };

    // Connect to the database
    if let Err(e) = DATABASE.connect(&base_ini_path).await {
        error!("{e}");

        return Ok(Some(message.add_error(
            ErrorType::Code,
            String::from("fail_database_connect"),
        )));
    }

    data.insert(
        "build_number".to_owned(),
        json!(std::include_str!("../.build-sha").to_string()),
    );

    data.insert(
        "version".to_owned(),
        json!(env!("CARGO_PKG_VERSION").to_string()),
    );

    data.insert("extdb_version".to_owned(), json!(DATABASE.extdb_version));

    info!("[post_init] Updating Arma global variables...");

    send_to_arma(message)?;

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
    send_to_arma(message)?;

    Ok(None)
}

async fn database_query(message: Message) -> MessageResult {
    let query = message.data;

    let name = match query.get("name") {
        Some(name) => name.as_str().unwrap_or(""),
        None => return Err("Missing name attribute for database query".into()),
    };

    let arguments = match query.get("arguments") {
        Some(arguments) => {
            let Some(arguments) = arguments.as_object() else {
                return Err("Failed to convert database arguments to object".into());
            };

            let mut transformed_args: HashMap<String, String> = HashMap::new();
            for (key, value) in arguments {
                let Some(value) = value.as_str() else {
                    return Err("Failed to convert argument value to string".into());
                };

                transformed_args.insert(key.to_string(), value.to_string());
            }

            transformed_args
        }
        None => return Err("Missing arguments attribute for database query".into()),
    };

    match DATABASE.query(&name, arguments).await {
        Ok(results) => Ok(Some(
            Message::new()
                .set_id(message.id)
                .set_type(Type::Query)
                .set_data(Data::from([("results".to_owned(), json!(results))])),
        )),
        Err(e) => Err(e),
    }
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
