use crate::*;
use crate::{database::Database, router::RoutingRequest};

use arma_rs::{Context, IntoArma};
use std::sync::Mutex as SyncMutex;
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    static ref DATABASE: Database = Database::new();
    static ref CALLBACK: Arc<SyncMutex<Option<Context>>> = Arc::new(SyncMutex::new(None));
}

pub async fn initialize(receiver: UnboundedReceiver<RoutingRequest>) {
    command_thread(receiver).await;
}

async fn command_thread(mut receiver: UnboundedReceiver<RoutingRequest>) {
    trace!("[arma::command_thread] Spawning");

    tokio::spawn(async move {
        // Command loop
        trace!("[arma::command_thread] Receiving");
        while let Some(command) = receiver.recv().await {
            let result: Option<Message> = match command {
                RoutingRequest::Query(message) => execute("query", *message).await,
                RoutingRequest::Method { name, message } => execute(name.as_str(), *message).await,
                RoutingRequest::ArmaInitialize { context } => {
                    trace!("[arma::command_thread] ArmaInitialize");
                    *lock!(CALLBACK) = Some(context);
                    continue;
                }
                c => {
                    error!(
                        "[arma#command_thread] ❌ Cannot process - Arma does not respond to {c}"
                    );
                    continue;
                }
            };

            // If a message is returned, send it back
            if let Some(m) = result {
                if let Err(e) = crate::ROUTER.route_to_bot(m) {
                    error!("[arma#command_thread] ❌ {e}");
                };
            }
        }
    });
}

async fn execute(name: &str, message: Message) -> Option<Message> {
    let message_id = message.id;

    trace!("[arma::execute] Executing {name} for message id:{message_id}");

    let result = match name {
        "query" => DATABASE.query(message).await,
        "post_initialization" => post_initialization(message).await,
        "call_function" => call_function(message).await,
        n => Err(
            format!("[arma#execute] Cannot process - Arma does not respond to method {n}").into(),
        ),
    };

    match result {
        Ok(m) => m,
        Err(e) => {
            error!("{e}");

            let message = Message::new(Type::Error)
                .set_id(message_id)
                .add_error(ErrorType::Code, "client_exception");

            Some(message)
        }
    }
}

fn send_to_arma(function: &str, message: Message) -> ESMResult {
    trace!(
        r#"[arma#send]
            function: {}
            message: {}
        "#,
        function,
        message
    );

    if std::env::var("ESM_IS_TERMINAL").is_ok() {
        return Ok(());
    }

    let message = vec![
        vec!["id".to_arma(), message.id.to_arma()],
        vec!["data".to_arma(), message.data.to_arma()],
        vec!["metadata".to_arma(), message.metadata.to_arma()],
    ];

    debug!("[arma#send] {message:?}");

    match &*lock!(CALLBACK) {
        Some(ctx) => {
            ctx.callback_data("exile_server_manager", function, Some(message));
            Ok(())
        }
        None => Err(
            "[arma#send] Cannot send - We are not connected to the Arma server at the moment"
                .into(),
        ),
    }
}

async fn post_initialization(message: Message) -> MessageResult {
    let data = retrieve_data!(message.data, Data::PostInit);

    // Get the base path to figure out where to look for the ini
    let base_ini_path = if data.extdb_path.is_empty() {
        crate::CONFIG.server_mod_name.clone()
    } else {
        data.extdb_path
    };

    // Connect to the database
    if let Err(e) = DATABASE.connect(&base_ini_path).await {
        error!("{e}");

        return Ok(Some(message.add_error(
            ErrorType::Code,
            String::from("fail_database_connect"),
        )));
    }

    // Call arma
    let token = &lock!(TOKEN_MANAGER);

    let message = message.set_data(Data::ArmaPostInit(ArmaPostInit {
        build_number: std::include_str!("../.build-sha").to_string(),
        community_id: token.community_id().to_string(),
        extdb_version: DATABASE.extdb_version,
        gambling_modifier: data.gambling_modifier,
        gambling_payout_base: data.gambling_payout,
        gambling_payout_randomizer_max: data.gambling_randomizer_max,
        gambling_payout_randomizer_mid: data.gambling_randomizer_mid,
        gambling_payout_randomizer_min: data.gambling_randomizer_min,
        gambling_win_percentage: data.gambling_win_chance,
        logging_add_player_to_territory: data.logging_add_player_to_territory,
        logging_demote_player: data.logging_demote_player,
        logging_exec: data.logging_exec,
        logging_gamble: data.logging_gamble,
        logging_modify_player: data.logging_modify_player,
        logging_pay_territory: data.logging_pay_territory,
        logging_promote_player: data.logging_promote_player,
        logging_remove_player_from_territory: data.logging_remove_player_from_territory,
        logging_reward_player: data.logging_reward,
        logging_transfer_poptabs: data.logging_transfer,
        logging_upgrade_territory: data.logging_upgrade_territory,
        logging_channel_id: data.logging_channel_id,
        server_id: token.server_id().to_string(),
        taxes_territory_payment: data.territory_payment_tax,
        taxes_territory_upgrade: data.territory_upgrade_tax,
        territory_admin_uids: data.territory_admins,
        version: env!("CARGO_PKG_VERSION").to_string(),
    }));

    send_to_arma("ESMs_system_process_postInit", message)?;

    info!("[arma#post_initialization] ✅ Connection established with bot");
    crate::READY.store(true, Ordering::SeqCst);

    Ok(None)
}

async fn call_function(message: Message) -> MessageResult {
    let metadata = retrieve_data!(message.metadata, Metadata::Command);

    // First, check to make sure the player has joined this server
    if !DATABASE.account_exists(&metadata.player.steam_uid).await? {
        return Ok(Some(message.add_error(
            esm_message::ErrorType::Code,
            String::from("player_account_does_not_exist"),
        )));
    }

    // If the command has a target, check to make sure they've joined the server
    if let Some(target_player) = &metadata.target {
        if !DATABASE.account_exists(&target_player.steam_uid).await? {
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
        _ => unreachable!(
            "[arma::call_extension] This is a bug. Data type \"{:?}\" has not been implemented yet",
            message.data
        ),
    };

    send_to_arma(function_name, message)?;

    Ok(None)
}
