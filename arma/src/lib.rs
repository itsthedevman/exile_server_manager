#[macro_use]
extern crate diesel;

#[macro_use]
extern crate log;

mod arma;
mod client;
mod command;
mod config;
mod database;
pub mod models;
pub mod schema;

// Various Packages
use arma_rs::{rv, rv_callback, rv_handler};
use chrono::prelude::*;
use esm_message::Data;
use esm_message::data::ServerInitialization;
use lazy_static::lazy_static;


use std::fs::File;
use std::io::Read;
use std::path::Path;
use std::{env, fs};

use parking_lot::RwLock;

// Logging
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;

use crate::arma::arma::Arma;
use crate::arma::data::Token;
use crate::config::Config;

lazy_static! {
    // Config data
    pub static ref CONFIG: Config = {
        let contents = match fs::read_to_string("@esm/config.yml") {
            Ok(file) => file,
            Err(_) => String::from(""),
        };

        let config: Config = match serde_yaml::from_str(&contents) {
            Ok(config) => config,
            Err(_) => Config::new()
        };

        config
    };

    // Controls if the extension can function or not.
    pub static ref READY: RwLock<bool> = RwLock::new(false);

    // A representation of the arma server. This is the driver for the extension so it needs to be kept in memory
    pub static ref ARMA: RwLock<Arma> = {
        // Placeholder data. This will be replaced in pre_init
        let token = Token::new(Vec::new(), Vec::new());
        let arma = Arma::new(token, Data::Empty(esm_message::Empty::new()));

        RwLock::new(arma)
    };
}

fn initialize_logger() {
    let log_pattern = "[{d(%Y-%m-%d %H:%M:%S)} {h({l})}] {m}{n}";
    let stdout = ConsoleAppender::builder()
        .encoder(Box::new(PatternEncoder::new(log_pattern)))
        .build();

    let logfile = FileAppender::builder()
        .encoder(Box::new(PatternEncoder::new(log_pattern)))
        .build(crate::CONFIG.logging_path.clone())
        .unwrap();

    let log_level = match crate::CONFIG.log_level.as_ref() {
        "debug" => log::LevelFilter::Debug,
        "trace" => log::LevelFilter::Trace,
        _ => log::LevelFilter::Info,
    };

    let config = LogConfig::builder()
        .appender(Appender::builder().build("stdout", Box::new(stdout)))
        .appender(Appender::builder().build("logfile", Box::new(logfile)))
        .build(
            Root::builder()
                .appender("logfile")
                .appender("stdout")
                .build(log_level),
        )
        .unwrap();

    log4rs::init_config(config).unwrap();

    info!(
        "\n----------------------------------\nWelcome to Exile Server Manager v{}\nLoaded config {:#?}\n----------------------------------",
        env!("CARGO_PKG_VERSION"),
        crate::CONFIG.to_hashmap()
    );
}

// pub fn a3_post_server_initialization(
//     _command: &Command,
//     parameters: &ServerPostInitialization,
//     extdb_version: u8,
// ) {
//     let community_id: Vec<String> = parameters.server_id.split("_").map(String::from).collect();
//     let community_id = community_id[0].clone();

//     rv_callback!(
//         "exile_server_manager",
//         "ESM_fnc_postServerInitialization",
//         community_id,                                    // ESM_CommunityID
//         parameters.server_id.clone(),                    // ESM_ServerID
//         extdb_version,                                   // ESM_ExtDBVersion
//         parameters.gambling_modifier,                    // ESM_Gambling_Modifier
//         parameters.gambling_payout,                      // ESM_Gambling_PayoutBase
//         parameters.gambling_randomizer_max,              // ESM_Gambling_PayoutRandomizerMax
//         parameters.gambling_randomizer_mid,              // ESM_Gambling_PayoutRandomizerMid
//         parameters.gambling_randomizer_min,              // ESM_Gambling_PayoutRandomizerMin
//         parameters.gambling_win_chance,                  // ESM_Gambling_WinPercentage
//         parameters.logging_add_player_to_territory,      // ESM_Logging_AddPlayerToTerritory
//         parameters.logging_demote_player,                // ESM_Logging_DemotePlayer
//         parameters.logging_exec,                         // ESM_Logging_Exec
//         parameters.logging_gamble,                       // ESM_Logging_Gamble
//         parameters.logging_modify_player,                // ESM_Logging_ModifyPlayer
//         parameters.logging_pay_territory,                // ESM_Logging_PayTerritory
//         parameters.logging_promote_player,               // ESM_Logging_PromotePlayer
//         parameters.logging_remove_player_from_territory, // ESM_Logging_RemovePlayerFromTerritory
//         parameters.logging_reward,                       // ESM_Logging_RewardPlayer
//         parameters.logging_transfer,                     // ESM_Logging_TransferPoptabs
//         parameters.logging_upgrade_territory,            // ESM_Logging_UpgradeTerritory
//         parameters.taxes_territory_payment,              // ESM_Taxes_TerritoryPayment
//         parameters.taxes_territory_upgrade,              // ESM_Taxes_TerritoryPayment
//         parameters.territory_admins.clone()              // ESM_TerritoryAdminUIDs
//     );
// }

// pub fn a3_reward(command: &Command, parameters: &Reward, metadata: &DefaultMetadata) {
//     rv_callback!(
//         "exile_server_manager",
//         "ESM_fnc_reward",
//         command.id.clone(),
//         parameters.clone(),
//         metadata.clone()
//     )
// }

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessible from callExtension
///////////////////////////////////////////////////////////////////////
#[rv(thread = true)]
pub fn pre_init(
    server_name: String,
    price_per_object: f32,
    territory_lifetime: f32,
    territory_data: String,
) {
    // Only allow this method to be called properly once
    if *READY.read() {
        warn!("[#pre_init] This endpoint can only be called once. Perhaps your server is boot looping?");
        return;
    }

    debug!("[#pre_init] ESM is booting");

    // Load and convert the esm.key file into a token
    let path = Path::new("@esm/esm.key");
    let mut file = match File::open(&path) {
        Ok(file) => file,
        Err(_) => {
            error!("[#pre_init] Failed to find \"esm.key\" file. If you haven't registered your server yet, please visit https://esmbot.com/wiki, click \"I am a Server Owner\", and follow the steps.");
            return;
        }
    };

    let mut key_contents = Vec::new();
    match file.read_to_end(&mut key_contents) {
        Ok(_) => {
            trace!("[#pre_init] esm.key - {:?}", key_contents);
        }
        Err(e) => {
            error!("[#pre_init] Failed to read \"esm.key\" file. Please check the file permissions and try again.\nReason: {}", e);
            return;
        }
    }

    let token: Token = match serde_json::from_slice(&key_contents) {
        Ok(token) => {
            trace!("[#pre_init] Token decoded - {:?}", token);
            token
        }
        Err(e) => {
            debug!("[#pre_init] ERROR - {}", e);
            error!("[#pre_init] Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
            return;
        }
    };

    // Using the data from the a3 server, create a data packet to be used whenever the server connects to the bot.
    let data = ServerInitialization {
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        server_start_time: Utc::now()
    };

    trace!("[#pre_init] Initialization Data - {:?}", data);

    let arma = Arma::new(token, Data::ServerInitialization(data));
    arma.connect();

    *ARMA.write() = arma;

    info!("[#pre_init] Boot completed");
}

#[rv_handler]
pub fn init() {
    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);
    lazy_static::initialize(&ARMA);

    // Start the logger
    initialize_logger();
}
