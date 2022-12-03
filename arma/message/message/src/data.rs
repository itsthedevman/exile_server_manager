use std::collections::HashMap;

use crate::NumberString;
use arma_rs::{FromArma, IntoArma, Value as ArmaValue};
use chrono::{DateTime, Utc};
use message_proc::ImplIntoArma;
use serde::{Deserialize, Serialize};

/// Attempts to retrieve a reference to the data. Panicking if the internal data does not match the provided type.
/// Usage:
///     retrieve_data!(&message, Init)
#[macro_export]
macro_rules! retrieve_data {
    ($enum:expr, $module:ident::$type:ident) => {{
        let data = match &$enum {
            $module::$type(ref v) => v.clone(),
            data => panic!(
                "Unexpected type {:?}. Expected: {}.",
                data,
                stringify!($type)
            ),
        };

        data
    }};
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq)]
#[serde(tag = "type", content = "content", rename_all = "snake_case")]
pub enum Data {
    Empty,
    Ping,
    Pong,
    Test(Test),

    // Init
    Init(Init),
    PostInit(Box<PostInit>),

    // Query
    Query(Query),
    QueryResult(QueryResult),

    // From Client
    SendToChannel(SendToChannel),

    // Arma
    Reward(Reward),
    Sqf(Sqf),
    SqfResult(SqfResult),
}

impl Default for Data {
    fn default() -> Self {
        Data::Empty
    }
}

impl IntoArma for Data {
    fn to_arma(&self) -> ArmaValue {
        match self {
            Data::Test(t) => t.to_arma(),
            Data::Init(i) => i.to_arma(),
            Data::PostInit(pi) => pi.to_arma(),
            Data::Query(q) => q.to_arma(),
            Data::QueryResult(qr) => qr.to_arma(),
            Data::Reward(r) => r.to_arma(),
            Data::SendToChannel(d) => d.to_arma(),
            Data::Sqf(s) => s.to_arma(),
            Data::SqfResult(s) => s.to_arma(),
            _ => ArmaValue::Null,
        }
    }
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
            Data::Test(d) => write!(f, "{:?}", d),
            Data::Init(d) => write!(f, "{:?}", d),
            Data::PostInit(d) => write!(f, "{:?}", d),
            Data::Query(d) => write!(f, "{:?}", d),
            Data::QueryResult(d) => write!(f, "{:?}", d),
            Data::SendToChannel(d) => write!(f, "{:?}", d),
            Data::Reward(d) => write!(f, "{:?}", d),
            Data::Sqf(d) => write!(f, "{:?}", d),
            Data::SqfResult(d) => write!(f, "{:?}", d),
            Data::Ping => write!(f, "Ping"),
            Data::Pong => write!(f, "Pong"),
        }
    }
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct Test {
    pub foo: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
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

#[derive(Serialize, Deserialize, Debug, Clone, ImplIntoArma, PartialEq, Eq)]
pub struct PostInit {
    // Set by the client
    #[serde(rename = "ESM_BuildNumber", alias = "ESM_BuildNumber", default)]
    pub build_number: String,

    #[serde(rename = "ESM_CommunityID", alias = "ESM_CommunityID")]
    pub community_id: String,

    // This is only used internally between esm_bot and esm_arma
    pub extdb_path: String,

    #[serde(rename = "ESM_ExtDBVersion", alias = "ESM_ExtDBVersion", default)]
    pub extdb_version: u8,

    #[serde(rename = "ESM_Gambling_Modifier", alias = "ESM_Gambling_Modifier")]
    pub gambling_modifier: NumberString,

    #[serde(rename = "ESM_Gambling_PayoutBase", alias = "ESM_Gambling_PayoutBase")]
    pub gambling_payout_base: NumberString,

    #[serde(
        rename = "ESM_Gambling_PayoutRandomizerMax",
        alias = "ESM_Gambling_PayoutRandomizerMax"
    )]
    pub gambling_payout_randomizer_max: NumberString,

    #[serde(
        rename = "ESM_Gambling_PayoutRandomizerMid",
        alias = "ESM_Gambling_PayoutRandomizerMid"
    )]
    pub gambling_payout_randomizer_mid: NumberString,

    #[serde(
        rename = "ESM_Gambling_PayoutRandomizerMin",
        alias = "ESM_Gambling_PayoutRandomizerMin"
    )]
    pub gambling_payout_randomizer_min: NumberString,

    #[serde(
        rename = "ESM_Gambling_WinPercentage",
        alias = "ESM_Gambling_WinPercentage"
    )]
    pub gambling_win_percentage: NumberString,

    #[serde(
        rename = "ESM_Logging_AddPlayerToTerritory",
        alias = "ESM_Logging_AddPlayerToTerritory"
    )]
    pub logging_add_player_to_territory: bool,

    #[serde(
        rename = "ESM_Logging_DemotePlayer",
        alias = "ESM_Logging_DemotePlayer"
    )]
    pub logging_demote_player: bool,

    #[serde(rename = "ESM_Logging_Exec", alias = "ESM_Logging_Exec")]
    pub logging_exec: bool,

    #[serde(rename = "ESM_Logging_Gamble", alias = "ESM_Logging_Gamble")]
    pub logging_gamble: bool,

    #[serde(
        rename = "ESM_Logging_ModifyPlayer",
        alias = "ESM_Logging_ModifyPlayer"
    )]
    pub logging_modify_player: bool,

    #[serde(
        rename = "ESM_Logging_PayTerritory",
        alias = "ESM_Logging_PayTerritory"
    )]
    pub logging_pay_territory: bool,

    #[serde(
        rename = "ESM_Logging_PromotePlayer",
        alias = "ESM_Logging_PromotePlayer"
    )]
    pub logging_promote_player: bool,

    #[serde(
        rename = "ESM_Logging_RemovePlayerFromTerritory",
        alias = "ESM_Logging_RemovePlayerFromTerritory"
    )]
    pub logging_remove_player_from_territory: bool,

    #[serde(
        rename = "ESM_Logging_RewardPlayer",
        alias = "ESM_Logging_RewardPlayer"
    )]
    pub logging_reward_player: bool,

    #[serde(
        rename = "ESM_Logging_TransferPoptabs",
        alias = "ESM_Logging_TransferPoptabs"
    )]
    pub logging_transfer_poptabs: bool,

    #[serde(
        rename = "ESM_Logging_UpgradeTerritory",
        alias = "ESM_Logging_UpgradeTerritory"
    )]
    pub logging_upgrade_territory: bool,

    #[serde(rename = "ESM_LoggingChannelID", alias = "ESM_LoggingChannelID")]
    pub logging_channel_id: String,

    #[serde(rename = "ESM_ServerID", alias = "ESM_ServerID")]
    pub server_id: String,

    #[serde(
        rename = "ESM_Taxes_TerritoryPayment",
        alias = "ESM_Taxes_TerritoryPayment"
    )]
    pub taxes_territory_payment: NumberString,

    #[serde(
        rename = "ESM_Taxes_TerritoryUpgrade",
        alias = "ESM_Taxes_TerritoryUpgrade"
    )]
    pub taxes_territory_upgrade: NumberString,

    #[serde(rename = "ESM_TerritoryAdminUIDs", alias = "ESM_TerritoryAdminUIDs")]
    pub territory_admin_uids: Vec<String>,

    // Set by the client
    #[serde(rename = "ESM_Version", alias = "ESM_Version", default)]
    pub version: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct Reward {
    pub items: Option<HashMap<String, NumberString>>,
    pub locker_poptabs: Option<NumberString>,
    pub player_poptabs: Option<NumberString>,
    pub respect: Option<NumberString>,
    pub vehicles: Option<Vec<HashMap<String, String>>>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct Sqf {
    pub execute_on: String,
    pub code: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct SqfResult {
    pub result: Option<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
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
#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct Query {
    pub arguments: HashMap<String, String>,
    pub name: String,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct QueryResult {
    pub results: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone, PartialEq, Eq, ImplIntoArma)]
pub struct SendToChannel {
    pub id: String,
    pub content: String,
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{data, metadata, Message, Metadata, Type};

    #[test]
    fn test_retrieve_data() {
        let mut message = Message::new().set_type(Type::Test);
        message.data = Data::Test(data::Test {
            foo: "testing".into(),
        });
        message.metadata = Metadata::Test(metadata::Test {
            foo: "testing".into(),
        });

        let result = retrieve_data!(&message.data, Data::Test);
        assert_eq!(result.foo, String::from("testing"));

        let result = retrieve_data!(&message.metadata, Metadata::Test);
        assert_eq!(result.foo, String::from("testing"));
    }

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
