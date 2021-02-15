#[macro_use]
extern crate diesel;

mod arma_server;
mod bot;
mod bot_command;
mod command;
mod database;
mod websocket_client;
pub mod schema;
pub mod models;

// ESM Packages
use arma_server::ArmaServer;
use bot::Bot;
use command::{Command, ServerPostInitialization};

// Various Packages
use arma_rs::{rv, rv_callback, rv_handler};
use chrono::prelude::*;
use lazy_static::lazy_static;
use serde_json::{json, Value};
use std::{collections::HashMap, env, fs, sync::RwLock};
use yaml_rust::{Yaml, YamlLoader};

// Logging
use log::*;
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config, Root};
use log4rs::encode::pattern::PatternEncoder;

lazy_static! {
    // Any metadata I need to have stored across threads
    pub static ref METADATA: RwLock<HashMap<&'static str, String>> = RwLock::new(HashMap::new());

    // Config data
    pub static ref CONFIG: Vec<Yaml> = {
        let contents = match fs::read_to_string("@ESM/config.yml") {
            Ok(file) => file,
            Err(_) => String::from(
                "
                    ws_url: ws://ws.esmbot.com
                ",
            ),
        };

        YamlLoader::load_from_str(&contents).unwrap()
    };

    // Contains a connection to the Discord bot and various methods involving it
    pub static ref BOT: Bot = Bot::new();

    // Data and methods regarding the Arma server
    pub static ref A3_SERVER: RwLock<ArmaServer> = RwLock::new(ArmaServer::new());
}

fn initialize_logger() {
    let logging_path = match crate::CONFIG[0]["logging_path"].as_str() {
        Some(name) => name,
        None => "@ESM/log/esm.log",
    };

    let stdout = ConsoleAppender::builder()
        .encoder(Box::new(PatternEncoder::new(
            "{d(%Y-%m-%d %H:%M:%S)} {l} - {m}\n",
        )))
        .build();

    let logfile = FileAppender::builder()
        .encoder(Box::new(PatternEncoder::new(
            "{d(%Y-%m-%d %H:%M:%S)} {l} - {m}\n",
        )))
        .build(logging_path)
        .unwrap();

    let config = Config::builder()
        .appender(Appender::builder().build("stdout", Box::new(stdout)))
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(
            Root::builder()
                .appender("logfile")
                .appender("stdout")
                .build(LevelFilter::Debug),
        )
        .unwrap();

    log4rs::init_config(config).unwrap();

    info!(
        "\n----------------------------------\nExile Server Manager v{}\n----------------------------------",
        env!("CARGO_PKG_VERSION")
    );
}

pub fn a3_post_server_initialization(
    _command: &Command,
    parameters: &ServerPostInitialization,
    extdb_version: u8,
) {
    let community_id: Vec<String> = parameters.server_id.split("_").map(String::from).collect();
    let community_id = community_id[0].clone();

    rv_callback!(
        "exile_server_manager",
        "ESM_fnc_postServerInitialization",
        community_id,                                    // ESM_CommunityID
        extdb_version,                                   // ESM_ExtDBVersion
        parameters.gambling_modifier,                    // ESM_Gambling_Modifier
        parameters.gambling_payout,                      // ESM_Gambling_PayoutBase
        parameters.gambling_randomizer_max,              // ESM_Gambling_PayoutRandomizerMax
        parameters.gambling_randomizer_mid,              // ESM_Gambling_PayoutRandomizerMid
        parameters.gambling_randomizer_min,              // ESM_Gambling_PayoutRandomizerMin
        parameters.gambling_win_chance,                  // ESM_Gambling_WinPercentage
        parameters.logging_add_player_to_territory,      // ESM_Logging_AddPlayerToTerritory
        parameters.logging_demote_player,                // ESM_Logging_DemotePlayer
        parameters.logging_exec,                         // ESM_Logging_Exec
        parameters.logging_gamble,                       // ESM_Logging_Gamble
        parameters.logging_modify_player,                // ESM_Logging_ModifyPlayer
        parameters.logging_pay_territory,                // ESM_Logging_PayTerritory
        parameters.logging_promote_player,               // ESM_Logging_PromotePlayer
        parameters.logging_remove_player_from_territory, // ESM_Logging_RemovePlayerFromTerritory
        parameters.logging_reward,                       // ESM_Logging_RewardPlayer
        parameters.logging_transfer,                     // ESM_Logging_TransferPoptabs
        parameters.logging_upgrade_territory,            // ESM_Logging_UpgradeTerritory
        parameters.reward_items.clone(),                 // ESM_RewardItems
        parameters.reward_locker_poptabs,                // ESM_RewardLockerPoptabs
        parameters.reward_player_poptabs,                // ESM_RewardPlayerPoptabs
        parameters.reward_respect,                       // ESM_RewardRespect
        parameters.server_id.clone(),                    // ESM_ServerID
        parameters.taxes_territory_payment,              // ESM_Taxes_TerritoryPayment
        parameters.taxes_territory_upgrade,              // ESM_Taxes_TerritoryPayment
        parameters.territory_admins.clone()              // ESM_TerritoryAdminUIDs
    );
}

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessible from callExtension
///////////////////////////////////////////////////////////////////////
#[rv(thread = true)]
fn pre_init(
    server_name: String,
    price_per_object: f32,
    territory_lifetime: f32,
    territory_data: String,
) {
    let territory_data: Vec<Value> = match serde_json::from_str(&territory_data) {
        Ok(data) => data,
        Err(e) => return error!("[pre_init] Unable to parse territory data: {}", e),
    };

    let package = json!({
        "server_name": server_name,
        "price_per_object": price_per_object,
        "territory_lifetime": territory_lifetime,
        "territory_data": territory_data,
        "server_start_time": Utc::now().to_rfc3339()
    });

    let package = package.to_string();
    METADATA
        .write()
        .unwrap()
        .insert("server_initialization", package.clone());
}

#[rv_handler]
fn init() {
    // Initialize the static instances to start everything
    lazy_static::initialize(&METADATA);
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&BOT);
    lazy_static::initialize(&A3_SERVER);

    // Start the logger
    initialize_logger();
}
