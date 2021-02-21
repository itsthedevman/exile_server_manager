use arma_rs::{ArmaValue, ToArma};
use serde::{Deserialize, Serialize};
use serde_json::json;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Command {
    pub id: String,
    pub command_name: String,
    pub parameters: Parameters,
    pub metadata: Metadata,
}

impl Command {
    pub fn reply_with_error(&self, message: String) {
        crate::BOT.send(
            Some(self.id.clone()),
            self.command_name.clone(),
            json!({ "error_message": message }).to_string(),
        )
    }

    pub fn reply_with_error_code<'a>(&self, code: &'a str) {
        crate::BOT.send(
            Some(self.id.clone()),
            self.command_name.clone(),
            json!({ "error_code": code }).to_string(),
        )
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Item {
    class_name: String,
    quantity: i64,
}

impl ToArma for Item {
    fn to_arma(&self) -> ArmaValue {
        ArmaValue::Array(vec![self.class_name.to_arma(), self.quantity.to_arma()])
    }
}

/* METADATA */
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(untagged)]
pub enum Metadata {
    Default(DefaultMetadata),
    Empty(EmptyMetadata)
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DefaultMetadata {
    pub user_id: String,
    pub user_name: String,
    pub user_mention: String,
    pub user_steam_uid: String,
}

impl ToArma for DefaultMetadata {
    fn to_arma(&self) -> ArmaValue {
        ArmaValue::Array(vec![self.user_id.to_arma(), self.user_name.to_arma(), self.user_mention.to_arma(), self.user_steam_uid.to_arma()])
    }
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct EmptyMetadata {}

/* PARAMETERS */
#[derive(Serialize, Deserialize, Debug, Clone)]
#[serde(tag = "type", content = "content")]
pub enum Parameters {
    ServerInitialization(ServerInitialization),
    ServerPostInitialization(ServerPostInitialization),
    Reward(Reward),
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ServerInitialization {}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct ServerPostInitialization {
    pub extdb_path: String,
    pub gambling_modifier: i64,
    pub gambling_payout: i64,
    pub gambling_randomizer_max: f64,
    pub gambling_randomizer_mid: f64,
    pub gambling_randomizer_min: f64,
    pub gambling_win_chance: i64,
    pub logging_add_player_to_territory: bool,
    pub logging_demote_player: bool,
    pub logging_exec: bool,
    pub logging_gamble: bool,
    pub logging_modify_player: bool,
    pub logging_pay_territory: bool,
    pub logging_promote_player: bool,
    pub logging_remove_player_from_territory: bool,
    pub logging_reward: bool,
    pub logging_transfer: bool,
    pub logging_upgrade_territory: bool,
    pub max_payment_count: i64,
    pub reward_items: Vec<Item>,
    pub reward_locker_poptabs: i64,
    pub reward_player_poptabs: i64,
    pub reward_respect: i64,
    pub server_id: String,
    pub taxes_territory_payment: i64,
    pub taxes_territory_upgrade: i64,
    pub territory_admins: Vec<String>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Reward {
    pub target_uid: String,
}

impl ToArma for Reward {
    fn to_arma(&self) -> ArmaValue {
        ArmaValue::Array(vec![self.target_uid.to_arma()])
    }
}
