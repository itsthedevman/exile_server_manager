#[macro_use]
extern crate log;

mod arma;
mod client;
mod config;
mod database;

// Various Packages
use arma_rs::{ArmaValue, ToArma, arma_value, rv, rv_callback, rv_handler};
use chrono::prelude::*;
use esm_message::*;
use lazy_static::lazy_static;
use uuid::Uuid;

use std::collections::HashMap;
use std::fmt::Debug;
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

use crate::arma::data::{RVOutput, Token};
use crate::arma::Arma;
use crate::config::Config;

const CHUNK_SIZE: usize = 8_000;

lazy_static! {
    /// Config data
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

    /// Controls if the extension can function or not.
    pub static ref READY: RwLock<bool> = RwLock::new(false);

    /// A representation of the arma server. This is the driver for the extension so it needs to be kept in memory
    pub static ref ARMA: RwLock<Arma> = {
        // Placeholder data. This will be replaced in pre_init
        let token = Token::new(Vec::new(), Vec::new());
        let arma = Arma::new(token, Data::Empty);

        RwLock::new(arma)
    };

    /// When sending large messages to Arma, the messages need to be chunked in order to avoid being "cut off"
    pub static ref CHUNKS: RwLock<HashMap<String, Vec<String>>> = RwLock::new(HashMap::new());
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
        "\n----------------------------------\nWelcome to Exile Server Manager v{} Build {}\nLoaded config {:#?}\n----------------------------------",
        env!("CARGO_PKG_VERSION"),
        env!("VERGEN_GIT_SHA_SHORT"),
        crate::CONFIG.to_hashmap()
    );
}

/// Loads the esm.key file from the disk and converts it to a Token
pub fn load_key() -> Option<Token> {
    let path = Path::new("@esm/esm.key");
    let mut file = match File::open(&path) {
        Ok(file) => file,
        Err(_) => {
            error!("[#load_key] Failed to find \"esm.key\" file. If you haven't registered your server yet, please visit https://esmbot.com/wiki, click \"I am a Server Owner\", and follow the steps.");
            return None;
        }
    };

    let mut key_contents = Vec::new();
    match file.read_to_end(&mut key_contents) {
        Ok(_) => {
            trace!("[#load_key] esm.key - {}", String::from_utf8_lossy(&key_contents));
        }
        Err(e) => {
            error!("[#load_key] Failed to read \"esm.key\" file. Please check the file permissions and try again.\nReason: {}", e);
            return None;
        }
    }

    let token: Token = match serde_json::from_slice(&key_contents) {
        Ok(token) => token,
        Err(e) => {
            debug!("[#load_key] ERROR - {}", e);
            error!("[#load_key] Corrupted \"esm.key\" detected. Please re-download your server key from the admin dashboard (https://esmbot.com/dashboard).");
            return None;
        }
    };

    trace!("[#load_key] Token decoded - {}", token);

    Some(token)
}

/// Facilitates sending a message to Arma only if this is using a A3 server. When in terminal mode, it just logs.
/// When sending a message to arma, the outbound message's size is checked and if it's larger than 9kb, it's split into <9kb chunks and associated to a ID
///     ESMs_system_extension_call will detect if it needs to make subsequent calls to the extension and perform any chunk rebuilding if needed
///
/// All data sent to Arma is in the following format (converted to a String): "[int_code, id, content]"
fn send_to_arma<D: ToArma + Debug>(function: &str, id: &Uuid, data: &D, metadata: &Metadata) {
    trace!("[#send_to_arma] \"{}\" -> ID: \"{:?}\"\nData: {:#?}\nMetadata: {:#?}", function, id, data, metadata);

    if env::var("ESM_IS_TERMINAL").is_ok() { return; }

    let message = arma_value!({ "id" => id, "data" => data, "metadata" => metadata });

    /*
        Convert the Arma value to a string and check its size.
        If the size is less than 10kb, build the [0, data] array and use RV callback to send it
        If the size is greater than 10kb, split the data into chunks and send the first chuck with the ID [1, id, data_chunk]
            Use ["next_chunk", "ID"] call ESMs_system_extension_call;
    */
    let data_string = message.to_string();
    let data_bytes = data_string.as_bytes().to_vec();
    let data_size = std::mem::size_of_val(&data_bytes);

    // Arma has a size limit. I'm not sure I'll ever hit it.
    if data_size > CHUNK_SIZE { panic!("Data is too large! Uncomment the chunking code."); }

    let output = RVOutput::new(None, 0, message.to_arma());

    rv_callback!("exile_server_manager", function, output);
}

/// Sends the post initialization data to the server
pub fn a3_post_init(arma: &mut Arma, message: &Message) {
    let data = retrieve_data!(message.data, Data::PostInit);
    let token = arma.client.token.read();

    send_to_arma(
        "ESMs_system_process_postInit",
        &message.id,
        &arma_value!({
            "ESM_BuildNumber" => env!("VERGEN_GIT_SHA_SHORT"),
            "ESM_CommunityID" => token.community_id(),
            "ESM_ExtDBVersion" => arma.database.extdb_version,
            "ESM_Gambling_Modifier" => data.gambling_modifier,
            "ESM_Gambling_PayoutBase" => data.gambling_payout,
            "ESM_Gambling_PayoutRandomizerMax" => data.gambling_randomizer_max,
            "ESM_Gambling_PayoutRandomizerMid" => data.gambling_randomizer_mid,
            "ESM_Gambling_PayoutRandomizerMin" => data.gambling_randomizer_min,
            "ESM_Gambling_WinPercentage" => data.gambling_win_chance,
            "ESM_Logging_AddPlayerToTerritory" => data.logging_add_player_to_territory,
            "ESM_Logging_DemotePlayer" => data.logging_demote_player,
            "ESM_Logging_Exec" => data.logging_exec,
            "ESM_Logging_Gamble" => data.logging_gamble,
            "ESM_Logging_ModifyPlayer" => data.logging_modify_player,
            "ESM_Logging_PayTerritory" => data.logging_pay_territory,
            "ESM_Logging_PromotePlayer" => data.logging_promote_player,
            "ESM_Logging_RemovePlayerFromTerritory" => data.logging_remove_player_from_territory,
            "ESM_Logging_RewardPlayer" => data.logging_reward,
            "ESM_Logging_TransferPoptabs" => data.logging_transfer,
            "ESM_Logging_UpgradeTerritory" => data.logging_upgrade_territory,
            "ESM_LoggingChannelID" => data.logging_channel_id,
            "ESM_ServerID" => token.server_id(),
            "ESM_Taxes_TerritoryPayment" => data.territory_payment_tax,
            "ESM_Taxes_TerritoryUpgrade" => data.territory_upgrade_tax,
            "ESM_TerritoryAdminUIDs" => data.territory_admins,
            "ESM_Version" => env!("CARGO_PKG_VERSION")
        }),
        &message.metadata
    );
}

pub fn a3_call_function(function_name: &str, message: &Message) {
    send_to_arma(function_name, &message.id, &message.data, &message.metadata);
}

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessible from callExtension
///////////////////////////////////////////////////////////////////////
/// Returns a UTC timestamp as a string.
#[rv]
pub fn utc_timestamp() -> String {
    RVOutput::new(None, 0, Utc::now().to_arma()).to_string()
}

#[rv]
pub fn log_level() -> String {
    RVOutput::new(None, 0, CONFIG.log_level.to_lowercase().to_arma()).to_string()
}

#[rv(thread = true)]
pub fn pre_init(
    server_name: String,
    price_per_object: NumberString,
    territory_lifetime: NumberString,
    territory_data: String,
    vg_enabled: bool,
    vg_max_sizes: String,
) {
    trace!(r#"[#pre_init] server_name: {:?}
            price_per_object: {:#?}
            territory_lifetime: {:#?}
            territory_data: {:#?}
            vg_enabled: {:#?}
            vg_max_sizes: {:#?}
        "#,
        server_name,price_per_object, territory_lifetime,
        territory_data, vg_enabled, vg_max_sizes
    );

    // Only allow this method to be called properly once
    if *READY.read() {
        warn!("[#pre_init] This endpoint can only be called once. Perhaps your server is boot looping?");
        return;
    }

    info!("[#pre_init] ESM is booting");

    // Load and convert the esm.key file into a token
    let token = match load_key() {
        Some(t) => t,
        None => return
    };

    // Using the data from the a3 server, create a data packet to be used whenever the server connects to the bot.
    let data = Init {
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        vg_enabled,
        vg_max_sizes,
        server_start_time: Utc::now(),
        extension_version: format!("{}+{}", env!("CARGO_PKG_VERSION"), env!("VERGEN_GIT_SHA_SHORT")),
    };

    trace!("[#pre_init] Initialization Data - {:?}", data);

    let arma = Arma::new(token, Data::Init(data));
    arma.client.connect();

    *ARMA.write() = arma;

    info!("[#pre_init] Boot completed");
}

#[rv(thread = true)]
pub fn event(id: String, data: ArmaValue, metadata: ArmaValue, errors: ArmaValue) {
    trace!("[#event] id: {:?}\ndata: {:#?}\nmetadata: {:#?}\nerrors: {:#?}", id, data, metadata, errors);

    let message = match Message::from_arma(Type::Event, id, data, metadata, errors) {
        Ok(m) => m,
        Err(e) => return error!("[#event] {}", e)
    };

    crate::ARMA.read().client.send_to_server(message);
}

#[rv(thread = true)]
pub fn send_to_channel(id: String, content: String) {
    trace!("[#send_to_channel] id: {:?}\ncontent: {:#?}", id, content);

    let mut message = Message::new(Type::Event);
    message.data = Data::SendToChannel(data::SendToChannel { id, content });

    crate::ARMA.read().client.send_to_server(message);
}

////////////////////////////////////////////////////////////
// DO NOT DEFINE ARMA ENDPOINTS BELOW
// rv_handler HAS TO BE THE LAST FUNCTION DEFINED
////////////////////////////////////////////////////////////
#[rv_handler]
pub fn init() {
    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);
    lazy_static::initialize(&ARMA);

    // Start the logger
    initialize_logger();
}
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////

#[cfg(test)]
mod tests {
    use regex::Regex;

    use super::*;

    #[test]
    fn it_returns_current_timestamp() {
        let result = utc_timestamp();

        // [null, 0, "2021-01-01T00:00:00.000000000+00:00"]
        let re = Regex::new(
            r#"^\[null, 0, "\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}\+\d{2}:\d{2}"\]$"#,
        ).unwrap();

        assert!(re.is_match(&result));
    }

    #[test]
    fn it_returns_log_level() {
        let result = log_level();
        assert_eq!(result, "[null, 0, \"debug\"]");
    }
}
