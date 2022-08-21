use arma_rs::{Context, IntoArma};
use esm_message::{retrieve_data, Data, Init, Message, Metadata};
use log::{debug, trace};
use serde::Serialize;
use serde_json::json;
use uuid::Uuid;

use crate::{
    database::Database,
    error::{ESMError, ESMResult},
};

type MessageResult = Result<Option<Message>, ESMError>;

pub struct Arma {
    pub database: Database,
    pub init: Init,
    callback: Option<Context>,
}

impl Default for Arma {
    fn default() -> Self {
        Arma {
            database: Database::new(),
            init: Init::default(),
            callback: None,
        }
    }
}

impl Arma {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn initialize(&mut self, init: Init, callback: Context) {
        self.init = init;
        self.callback = Some(callback);
    }

    pub fn send<D: Serialize + IntoArma + std::fmt::Debug>(
        &self,
        function: &str,
        id: &Uuid,
        data: &D,
        metadata: &Metadata,
    ) -> ESMResult {
        trace!(
            r#"[arma#send]
                function: {}
                id: {:?}
                data: {:?}
                metadata: {:?}
            "#,
            function,
            id,
            data,
            metadata
        );

        if std::env::var("ESM_IS_TERMINAL").is_ok() {
            return Ok(());
        }

        let message = vec![
            vec!["id".to_arma(), id.to_arma()],
            vec!["data".to_arma(), data.to_arma()],
            vec!["metadata".to_arma(), metadata.to_arma()],
        ];

        debug!("[arma#send]\n{message:?}");

        match &self.callback {
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

    pub fn extdb_version(&self) -> u8 {
        self.database.extdb_version
    }

    pub fn post_initialization(&mut self, mut message: Message) -> MessageResult {
        let data = retrieve_data!(message.data, Data::PostInit);

        // Get the base path to figure out where to look for the ini
        let base_ini_path = if data.extdb_path.is_empty() {
            String::from("@ExileServer")
        } else {
            data.extdb_path
        };

        // Connect to the database
        if self.database.connect(base_ini_path).is_err() {
            message.add_error(
                esm_message::ErrorType::Code,
                String::from("fail_database_connect"),
            );

            return Ok(Some(message));
        }

        // Call arma
        let bot = crate::BOT.read();
        let token = bot.token();
        let community_id = match token.community_id() {
            Some(t) => t,
            None => {
                message.add_error(esm_message::ErrorType::Code, String::from("invalid_token"));

                return Ok(Some(message));
            }
        };

        let server_id = match token.server_id() {
            Some(t) => t,
            None => {
                message.add_error(esm_message::ErrorType::Code, String::from("invalid_token"));

                return Ok(Some(message));
            }
        };

        self.send(
            "ESMs_system_process_postInit",
            &message.id,
            &json!({
                "ESM_BuildNumber": std::include_str!("../.build-sha"),
                "ESM_CommunityID": community_id,
                "ESM_ExtDBVersion": self.extdb_version(),
                "ESM_Gambling_Modifier": data.gambling_modifier,
                "ESM_Gambling_PayoutBase": data.gambling_payout,
                "ESM_Gambling_PayoutRandomizerMax": data.gambling_randomizer_max,
                "ESM_Gambling_PayoutRandomizerMid": data.gambling_randomizer_mid,
                "ESM_Gambling_PayoutRandomizerMin": data.gambling_randomizer_min,
                "ESM_Gambling_WinPercentage": data.gambling_win_chance,
                "ESM_Logging_AddPlayerToTerritory": data.logging_add_player_to_territory,
                "ESM_Logging_DemotePlayer": data.logging_demote_player,
                "ESM_Logging_Exec": data.logging_exec,
                "ESM_Logging_Gamble": data.logging_gamble,
                "ESM_Logging_ModifyPlayer": data.logging_modify_player,
                "ESM_Logging_PayTerritory": data.logging_pay_territory,
                "ESM_Logging_PromotePlayer": data.logging_promote_player,
                "ESM_Logging_RemovePlayerFromTerritory": data.logging_remove_player_from_territory,
                "ESM_Logging_RewardPlayer": data.logging_reward,
                "ESM_Logging_TransferPoptabs": data.logging_transfer,
                "ESM_Logging_UpgradeTerritory": data.logging_upgrade_territory,
                "ESM_LoggingChannelID": data.logging_channel_id,
                "ESM_ServerID": server_id,
                "ESM_Taxes_TerritoryPayment": data.territory_payment_tax,
                "ESM_Taxes_TerritoryUpgrade": data.territory_upgrade_tax,
                "ESM_TerritoryAdminUIDs": data.territory_admins,
                "ESM_Version": env!("CARGO_PKG_VERSION")
            }),
            &message.metadata,
        )?;

        Ok(None)
    }

    pub fn call_function(&self, mut message: Message) -> MessageResult {
        let metadata = retrieve_data!(message.metadata, Metadata::Command);

        // First, check to make sure the player has joined this server
        if !self.database.account_exists(&metadata.player.steam_uid) {
            message.add_error(
                esm_message::ErrorType::Code,
                String::from("player_account_does_not_exist"),
            );
            return Ok(Some(message));
        }

        // If the command has a target, check to make sure they've joined the server
        if let Some(target_player) = &metadata.target {
            if !self.database.account_exists(&target_player.steam_uid) {
                message.add_error(
                    esm_message::ErrorType::Code,
                    String::from("target_account_does_not_exist"),
                );
                return Ok(Some(message));
            }
        }

        // Now process the message
        let function_name = match message.data {
            Data::Reward(_) => "ESMs_command_reward",
            Data::Sqf(_) => "ESMs_command_sqf",
            _ => unreachable!("[arma::call_extension] This is a bug. Data type \"{:?}\" has not been implemented yet", message.data)
        };

        self.send(function_name, &message.id, &message.data, &message.metadata)?;
        Ok(None)
    }
}
