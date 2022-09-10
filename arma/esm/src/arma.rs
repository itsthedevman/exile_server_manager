use crate::*;
use crate::{database::Database, router::RoutingCommand};

use arma_rs::{Context, IntoArma};
use serde_json::json;
use tokio::sync::mpsc::UnboundedReceiver;

lazy_static! {
    static ref DATABASE: Database = Database::new();
    static ref CALLBACK: Arc<Mutex<Option<Context>>> = Arc::new(Mutex::new(None));
}

pub async fn initialize(receiver: UnboundedReceiver<RoutingCommand>) {
    command_thread(receiver).await;
}

async fn command_thread(mut receiver: UnboundedReceiver<RoutingCommand>) {
    tokio::spawn(async move {
        // Command loop
        while let Some(command) = receiver.recv().await {
            let result: Option<Message> = match command {
                RoutingCommand::Query(message) => execute("query", *message).await,
                RoutingCommand::Method { name, message } => execute(name.as_str(), *message).await,
                RoutingCommand::ArmaInitialize { context } => {
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
                    error!("{e}");
                };
            }
        }
    });
}

async fn execute(name: &str, message: Message) -> Option<Message> {
    let message_id = message.id;

    let result = match name {
        "query" => DATABASE.query(message).await,
        "post_initialization" => post_initialization(message).await,
        "call_function" => call_function(message).await,
        n => Err(
            format!("[arma#execute] Cannot process - Arma does not respond to method {n}").into(),
        ),
    };

    if let Err(e) = result {
        error!("{e}");
        let message = Message::new(Type::Error)
            .set_id(message_id)
            .add_error(ErrorType::Code, "client_exception");
    }

    None
}

async fn send_to_arma(function: &str, message: Message) -> ESMResult {
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

    trace!("[arma#send] {message:?}");

    match &*lock!(CALLBACK) {
        Some(ctx) => {
            ctx.callback("exile_server_manager", function, Some(message));
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
    // send_to_arma(
    //     "ESMs_system_process_postInit",
    //     &message.id,
    //     &json!({
    //         "ESM_BuildNumber": std::include_str!("../.build-sha"),
    //         "ESM_CommunityID": token.community_id(),
    //         "ESM_ExtDBVersion": DATABASE.extdb_version,
    //         "ESM_Gambling_Modifier": data.gambling_modifier.parse::<f32>()?,
    //         "ESM_Gambling_PayoutBase": data.gambling_payout.parse::<f32>()?,
    //         "ESM_Gambling_PayoutRandomizerMax": data.gambling_randomizer_max.parse::<f32>()?,
    //         "ESM_Gambling_PayoutRandomizerMid": data.gambling_randomizer_mid.parse::<f32>()?,
    //         "ESM_Gambling_PayoutRandomizerMin": data.gambling_randomizer_min.parse::<f32>()?,
    //         "ESM_Gambling_WinPercentage": data.gambling_win_chance.parse::<f32>()?,
    //         "ESM_Logging_AddPlayerToTerritory": data.logging_add_player_to_territory,
    //         "ESM_Logging_DemotePlayer": data.logging_demote_player,
    //         "ESM_Logging_Exec": data.logging_exec,
    //         "ESM_Logging_Gamble": data.logging_gamble,
    //         "ESM_Logging_ModifyPlayer": data.logging_modify_player,
    //         "ESM_Logging_PayTerritory": data.logging_pay_territory,
    //         "ESM_Logging_PromotePlayer": data.logging_promote_player,
    //         "ESM_Logging_RemovePlayerFromTerritory": data.logging_remove_player_from_territory,
    //         "ESM_Logging_RewardPlayer": data.logging_reward,
    //         "ESM_Logging_TransferPoptabs": data.logging_transfer,
    //         "ESM_Logging_UpgradeTerritory": data.logging_upgrade_territory,
    //         "ESM_LoggingChannelID": data.logging_channel_id,
    //         "ESM_ServerID": token.server_id(),
    //         "ESM_Taxes_TerritoryPayment": data.territory_payment_tax.parse::<f32>()?,
    //         "ESM_Taxes_TerritoryUpgrade": data.territory_upgrade_tax.parse::<f32>()?,
    //         "ESM_TerritoryAdminUIDs": data.territory_admins,
    //         "ESM_Version": env!("CARGO_PKG_VERSION")
    //     }),
    //     &message.metadata,
    // )?;

    Ok(None)
}

async fn call_function(mut message: Message) -> MessageResult {
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

    // self.send(function_name, &message.id, &message.data, &message.metadata)?;
    Ok(None)
}
