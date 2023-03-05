use crate::database::Database;
use crate::*;

use arma_rs::{Context, IntoArma};
use std::sync::Mutex as SyncMutex;
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    static ref DATABASE: Database = Database::new();
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
        "query" => DATABASE.query(message).await,
        "post_initialization" => post_initialization(message).await,
        "call_function" => call_arma_function(message).await,
        n => Err(format!("[execute] Cannot process - Arma does not respond to method {n}").into()),
    };

    match result {
        Ok(m) => m,
        Err(e) => {
            error!("{e}");

            let message = Message::new()
                .set_id(message_id)
                .add_error(e.error_type, e.error_content);

            Some(message)
        }
    }
}

fn send_to_arma(function: &str, message: Message) -> ESMResult {
    trace!(
        r#"[send]
            function: {}
            message: {}
        "#,
        function,
        message
    );

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
        None => {
            Err("[send] Cannot send - We are not connected to the Arma server at the moment".into())
        }
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

    send_to_arma("ESMs_system_process_postInit", message)?;

    info!("[post_initialization] ✅ Connection established with esm_bot");
    crate::READY.store(true, Ordering::SeqCst);

    Ok(None)
}

async fn call_arma_function(message: Message) -> MessageResult {
    let Metadata::Command(ref metadata) = message.metadata else {
        return Err("".into());
    };

    // First, check to make sure the player has joined this server
    if !DATABASE
        .check_account_exists(&metadata.player.steam_uid)
        .await?
    {
        return Ok(Some(message.add_error(
            esm_message::ErrorType::Code,
            String::from("player_account_does_not_exist"),
        )));
    }

    // If the command has a target, check to make sure they've joined the server
    if let Some(target_player) = &metadata.target {
        if !DATABASE
            .check_account_exists(&target_player.steam_uid)
            .await?
        {
            return Ok(Some(message.add_error(
                esm_message::ErrorType::Code,
                String::from("target_account_does_not_exist"),
            )));
        }
    }

    // Now process the message
    let function_name = match message.data {
        Data::Reward(_) => "ESMs_command_reward",
        Data::Sqf(_) => "ESMs_command_sqf",
        _ => {
            return Err(format!(
                "[call_extension] This is a bug. Data type \"{:?}\" has not been implemented yet",
                message.data
            )
            .into())
        }
    };

    send_to_arma(function_name, message)?;

    Ok(None)
}
