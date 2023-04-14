use std::collections::HashMap;

use crate::NumberString;
use arma_rs::{FromArma, IntoArma, Value as ArmaValue};
use chrono::{DateTime, Utc};
use message_proc::Arma;
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Default, Arma)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum Data {
    ///////////////////
    /// Internal
    ///////////////////
    #[default]
    Empty,
    Ping,
    Pong,
    Test(Test), // TODO(Improve or remove)

    Query(Query),

    ///////////////////
    /// Bot bound
    ///////////////////
    Init(Init),
    SqfResult(SqfResult),
    QueryResult(QueryResult),
    SendToChannel(SendToChannel),

    ///////////////////
    /// Arma bound
    ///////////////////
    #[arma(function = "ESMs_system_process_postInit")]
    PostInit(Box<PostInit>),

    #[arma(function = "ESMs_command_add")]
    Add(Add),

    #[arma(function = "ESMs_command_reward")]
    Reward(Reward),

    #[arma(function = "ESMs_command_sqf")]
    Sqf(Sqf),
}

impl FromArma for Data {
    fn from_arma(string: String) -> Result<Self, String> {
        crate::parser::Parser::from_arma(&string)
    }
}

impl std::fmt::Display for Data {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match &self {
            Data::Empty => write!(f, "Empty"),
            t => write!(f, "{:?}", t),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Test {
    pub foo: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Init {
    pub extension_version: String,
    pub price_per_object: NumberString,
    pub server_name: String,
    pub server_start_time: DateTime<Utc>,
    pub territory_data: String,
    pub territory_lifetime: NumberString,
    pub vg_enabled: bool,
    pub vg_max_sizes: String,
}

impl Default for Init {
    fn default() -> Self {
        Init {
            extension_version: "".into(),
            price_per_object: "".into(),
            server_name: "".into(),
            server_start_time: Utc::now(),
            territory_data: "".into(),
            territory_lifetime: "".into(),
            vg_enabled: false,
            vg_max_sizes: "".into(),
        }
    }
}

impl Init {
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = vec![];

        if self.extension_version.is_empty() {
            errors.push("\"extension_version\" was not provided".into());
        }

        if let Err(e) = self.price_per_object.parse::<usize>() {
            errors.push(format!(
                "Could not parse \"{}\" provided to \"price_per_object\" - {}",
                self.price_per_object, e
            ));
        }

        if self.server_name.is_empty() {
            errors.push("\"server_name\" was not provided".into());
        }

        if self.territory_data.is_empty() {
            errors.push("\"territory_data\" was not provided".into());
        }

        if let Err(e) = self.territory_lifetime.parse::<usize>() {
            errors.push(format!(
                "Could not parse \"{}\" provided to \"territory_lifetime\" - {}",
                self.territory_lifetime, e
            ));
        }

        if self.vg_max_sizes.is_empty() {
            errors.push("\"vg_max_sizes\" was not provided".into());
        }

        if errors.is_empty() {
            Ok(())
        } else {
            Err(errors)
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
pub struct PostInit {
    // Set by the client
    #[serde(default)]
    pub build_number: String,

    pub community_id: String,
    pub extdb_path: String, // This is only used internally between esm_bot and esm_arma

    #[serde(default)]
    pub extdb_version: u8,

    pub gambling_modifier: NumberString,
    pub gambling_payout_base: NumberString,
    pub gambling_payout_randomizer_max: NumberString,
    pub gambling_payout_randomizer_mid: NumberString,
    pub gambling_payout_randomizer_min: NumberString,
    pub gambling_win_percentage: NumberString,
    pub logging_add_player_to_territory: bool,
    pub logging_demote_player: bool,
    pub logging_exec: bool,
    pub logging_gamble: bool,
    pub logging_modify_player: bool,
    pub logging_pay_territory: bool,
    pub logging_promote_player: bool,
    pub logging_remove_player_from_territory: bool,
    pub logging_reward_player: bool,
    pub logging_transfer_poptabs: bool,
    pub logging_upgrade_territory: bool,
    pub logging_channel_id: String,
    pub server_id: String,
    pub taxes_territory_payment: NumberString,
    pub taxes_territory_upgrade: NumberString,
    pub territory_admin_uids: Vec<String>,

    // Set by the client
    #[serde(default)]
    pub version: String,
}

impl arma_rs::IntoArma for PostInit {
    // Custom implementation because it doesn't use all of the fields
    fn to_arma(&self) -> arma_rs::Value {
        serde_json::json!({
            "ESM_BuildNumber": self.build_number,
            "ESM_CommunityID": self.community_id,
            "ESM_ExtDBVersion": self.extdb_version,
            "ESM_Gambling_Modifier": self.gambling_modifier,
            "ESM_Gambling_PayoutBase": self.gambling_payout_base,
            "ESM_Gambling_PayoutRandomizerMax": self.gambling_payout_randomizer_max,
            "ESM_Gambling_PayoutRandomizerMid": self.gambling_payout_randomizer_mid,
            "ESM_Gambling_PayoutRandomizerMin": self.gambling_payout_randomizer_min,
            "ESM_Gambling_WinPercentage": self.gambling_win_percentage,
            "ESM_Logging_AddPlayerToTerritory": self.logging_add_player_to_territory,
            "ESM_Logging_DemotePlayer": self.logging_demote_player,
            "ESM_Logging_Exec": self.logging_exec,
            "ESM_Logging_Gamble": self.logging_gamble,
            "ESM_Logging_ModifyPlayer": self.logging_modify_player,
            "ESM_Logging_PayTerritory": self.logging_pay_territory,
            "ESM_Logging_PromotePlayer": self.logging_promote_player,
            "ESM_Logging_RemovePlayerFromTerritory": self.logging_remove_player_from_territory,
            "ESM_Logging_RewardPlayer": self.logging_reward_player,
            "ESM_Logging_TransferPoptabs": self.logging_transfer_poptabs,
            "ESM_Logging_UpgradeTerritory": self.logging_upgrade_territory,
            "ESM_LoggingChannelID": self.logging_channel_id,
            "ESM_ServerID": self.server_id,
            "ESM_Taxes_TerritoryPayment": self.taxes_territory_payment,
            "ESM_Taxes_TerritoryUpgrade": self.taxes_territory_upgrade,
            "ESM_TerritoryAdminUIDs": self.territory_admin_uids,
            "ESM_Version": self.version,
        })
        .to_arma()
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Reward {
    pub items: Option<HashMap<String, NumberString>>,
    pub locker_poptabs: Option<NumberString>,
    pub player_poptabs: Option<NumberString>,
    pub respect: Option<NumberString>,
    pub vehicles: Option<Vec<HashMap<String, String>>>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Sqf {
    pub execute_on: String,
    pub code: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct SqfResult {
    pub result: Option<String>,
}

#[derive(Serialize, Deserialize, Default, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Event {
    pub event_type: String,
    pub triggered_at: DateTime<Utc>,
}

// territory
//   - territory_id: Returns a single territory that matches this ID
// territories:
//   - uid: Returns any territories the target uid is a part of
//   - (no arguments): Lists all territories
// player_info_account_only
// leaderboard
// leaderboard_deaths
// leaderboard_score
// restore
// reset_player
// reset_all
// get_territory_id_from_hash
// set_custom_territory_id
// get_hash_from_id
// get_payment_count
// increment_payment_counter
// reset_payment_counter
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, Arma)]
pub struct Query {
    pub arguments: HashMap<String, String>,
    pub name: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq, Eq, Arma)]
pub struct QueryResult {
    pub results: Vec<String>,
}

impl QueryResult {
    pub fn new(results: Vec<String>) -> Self {
        QueryResult { results }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq, Eq, Arma)]
pub struct SendToChannel {
    pub id: String,
    pub content: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, Default, PartialEq, Eq, Arma)]
pub struct Add {
    pub territory_id: String,
}

////////////////////////////////////////////////////////////////////////////////
/// Tests
////////////////////////////////////////////////////////////////////////////////
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_to_arma() {
        let data = Test {
            foo: "bar".to_string(),
        };

        assert_eq!(data.to_arma().to_string(), "[[\"foo\",\"bar\"]]");

        let mut items = HashMap::new();
        items.insert("key_1".to_string(), "value_1".to_string());

        let data = Reward {
            items: Some(items),
            locker_poptabs: Some("1".to_string()),
            player_poptabs: Some("3".to_string()),
            respect: Some("2".to_string()),
            vehicles: None,
        };

        assert_eq!(data.to_arma().to_string(), "[[\"items\",[[\"key_1\",\"value_1\"]]],[\"locker_poptabs\",\"1\"],[\"player_poptabs\",\"3\"],[\"respect\",\"2\"],[\"vehicles\",null]]");
    }

    #[test]
    fn is_init_valid() {
        assert!(Init::default().validate().is_err());
        assert!(Init {
            extension_version: "version".into(),
            price_per_object: "5".into(),
            server_name: "server name".into(),
            server_start_time: Utc::now(),
            territory_data: "[]".into(),
            territory_lifetime: "7".into(),
            vg_enabled: false,
            vg_max_sizes: "[]".into(),
        }
        .validate()
        .is_ok());

        assert_eq!(
            Init {
                extension_version: "".into(),
                price_per_object: "-1".into(),
                server_name: "server name".into(),
                server_start_time: Utc::now(),
                territory_data: "".into(),
                territory_lifetime: "7".into(),
                vg_enabled: false,
                vg_max_sizes: "[]".into(),
            }
            .validate()
            .unwrap_err(),
            vec![
                "\"extension_version\" was not provided".to_string(),
                "Could not parse \"-1\" provided to \"price_per_object\" - invalid digit found in string".into(),
                "\"territory_data\" was not provided".into()
            ]
        );
    }
}
