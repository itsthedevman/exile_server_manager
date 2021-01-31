use arma_rs::{ArmaValue, ToArma};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;

#[derive(Serialize, Deserialize, Debug)]
#[serde(untagged)]
pub enum Parameters {
    ServerPostInitialization(ServerPostInitialization),

    // The empty structs need to stay at the bottom because they'll deserialize no matter what
    ServerInitialization(ServerInitialization),
}

#[derive(Serialize, Deserialize, Debug)]
pub struct ServerInitialization {}

#[derive(Serialize, Deserialize, Debug)]
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
    pub logging_path: String,
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

#[derive(Serialize, Deserialize, Debug)]
pub struct Command {
    pub id: String,
    pub command_name: String,
    pub parameters: Parameters,
    pub metadata: HashMap<String, Value>,
}

#[derive(Serialize, Deserialize, Debug)]
pub struct Item {
    class_name: String,
    quantity: i64,
}

impl ToArma for Item {
    fn to_arma(&self) -> ArmaValue {
        ArmaValue::Array(vec![self.class_name.to_arma(), self.quantity.to_arma()])
    }
}
