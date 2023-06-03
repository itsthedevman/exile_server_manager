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
    let function = message.data.sqf_function();
    if function.is_empty() {
        error!(
            "[send_to_arma] Dropping message with data type {:?} since it does not have a registered SQF function",
            message.data
        );

        return Err("".into());
    }

    trace!(
        r#"[send_to_arma]
            function: {}
            message: {}
        "#,
        function,
        message
    );

    info!("[send_to_arma] {message}");

    let message = vec![
        vec!["id".to_arma(), message.id.to_arma()],
        vec!["data".to_arma(), message.data.to_arma()],
        vec!["metadata".to_arma(), message.metadata.to_arma()],
    ];

    match &*lock!(CALLBACK) {
        Some(ctx) => {
            ctx.callback_data("exile_server_manager", function, Some(message));
            Ok(())
        }
        None => Err(
            "[send_to_arma] Cannot send - We are not connected to the Arma server at the moment"
                .into(),
        ),
    }
}

async fn post_initialization(mut message: Message) -> MessageResult {
    let Data::PostInit(ref mut data) = message.data else {
        return Err("".into());
    };

    // Get the base path to figure out where to look for the ini
    let base_ini_path = if data.extdb_path.is_empty() {
        crate::CONFIG.server_mod_name.clone()
    } else {
        data.extdb_path.to_owned()
    };

    // Connect to the database
    if let Err(e) = DATABASE.connect(&base_ini_path).await {
        error!("{e}");

        return Ok(Some(message.add_error(
            ErrorType::Code,
            String::from("fail_database_connect"),
        )));
    }

    data.build_number = std::include_str!("../.build-sha").to_string();
    data.version = env!("CARGO_PKG_VERSION").to_string();
    data.extdb_version = DATABASE.extdb_version;

    send_to_arma(message)?;

    info!("[post_initialization] ✅ Connection established with esm_bot");
    crate::READY.store(true, Ordering::SeqCst);

    Ok(None)
}

async fn call_arma_function(mut message: Message) -> MessageResult {
    let Metadata::Command(ref metadata) = message.metadata else {
        return Err("[call_arma_function] Invalid data type provided".into());
    };

    // First, check to make sure the player has joined this server
    if !DATABASE
        .account_verification(&metadata.player.steam_uid)
        .await?
    {
        return Ok(Some(message.add_error(
            esm_message::ErrorType::Code,
            String::from("account_does_not_exist"),
        )));
    }

    // If the data has a territory_id, check it against the database
    if let Some(territory) = message.data.territory() {
        let Territory::Encoded { id } = territory else {
            return Err(format!("[call_arma_function] TerritoryID parsed into {:?}", territory).into());
        };

        // Replace with the decoded one
        *territory = Territory::Decoded {
            id: id.to_string(),
            database_id: DATABASE.decode_territory_id(&id).await?,
        };

        trace!("[call_arma_function] Decoded territory ID: {territory:#?}");
    }

    // Now process the message
    send_to_arma(message)?;

    Ok(None)
}

async fn database_query(message: Message) -> MessageResult {
    let Data::Query(ref query) = message.data else {
        return Err("[query] Invalid data type".into());
    };

    let query_result = DATABASE.query(&query.name, &query.arguments).await;
    match query_result {
        Ok(results) => Ok(Some(
            Message::new()
                .set_id(message.id)
                .set_type(Type::Query)
                .set_data(Data::QueryResult(results)),
        )),
        Err(e) => Err(e),
    }
}
