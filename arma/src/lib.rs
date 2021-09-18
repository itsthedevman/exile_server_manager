#[macro_use]
extern crate log;

mod arma;
mod client;
mod config;
mod database;
pub mod models;

// Various Packages
use arma_rs::{ArmaValue, ToArma, arma_value, rv, rv_callback, rv_handler};
use chrono::prelude::*;
use esm_message::{Data, Message, Type, retrieve_data};
use lazy_static::lazy_static;
use uuid::Uuid;
use esm_message::data::*;

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

/// Facilitates sending a message to Arma only if this is using a A3 server. When in terminal mode, it just logs.
/// When sending a message to arma, the outbound message's size is checked and if it's larger than 9kb, it's split into <9kb chunks and associated to a ID
///     ESMs_system_extension_call will detect if it needs to make subsequent calls to the extension and perform any chunk rebuilding if needed
///
/// All data sent to Arma is in the following format (converted to a String): "[int_code, id, content]"
fn send_to_arma<D: ToArma + Debug + ToString>(function: &'static str, data: D) {
    if env::var("ESM_IS_TERMINAL").is_ok() {
        info!("Function: {}\nData: {:#?}", function, data);
        return;
    }

    /*
        Convert the Arma value to a string and check its size.
        If the size is less than 10kb, build the [0, data] array and use RV callback to send it
        If the size is greater than 10kb, split the data into chunks and send the first chuck with the ID [1, id, data_chunk]
            Use ["next_chunk", "ID"] call ESMs_system_extension_call;
    */
    let data_string = data.to_string();
    let data_bytes = data_string.as_bytes().to_vec();
    let data_size = std::mem::size_of_val(&data_bytes);

    // Arma has a size limit. I'm not sure I'll ever hit it.
    if data_size > CHUNK_SIZE { panic!("Data is too large! Uncomment the chunking code."); }

    let output = RVOutput::new(None, 0, data.to_arma()).to_string();
    rv_callback!(
        "exile_server_manager",
        function,
        output
    );

    // UNCOMMENT THIS AND next_chunk IF NEEDED.
    // I wrote this in an attempt to fix a bug. But it didn't work
    // // Create a ID for this chunk
    // let id = Uuid::new_v4();

    // // The data size is too big, chunk it. Also, flip it around so pop will give us the next in the queue
    // let mut chunks: Vec<String> = data_bytes.chunks(CHUNK_SIZE).map(|x| String::from_utf8(x.to_vec()).unwrap()).collect();
    // chunks.reverse();

    // // Retrieve the first chunk, the rest will be written to the chunks
    // let first_chunk = chunks.pop();

    // let mut chunk_writer = CHUNKS.write();
    // chunk_writer.insert(id.to_string(), chunks);

    // // Release our write access immediately.
    // drop(chunk_writer);

    // let output = RVOutput::new(Some(id), 1, first_chunk.to_arma()).to_string();

    // debug!("[send_to_arma] First Chunk: {}", output);

    // // Send the first chunk to Arma
    // rv_callback!(
    //     "exile_server_manager",
    //     function,
    //     output
    // )
}

/// Logs a message to the server's RPT using ESMs_util_log
pub fn a3_log(message: String) {
    send_to_arma("ESMs_util_log", arma_value!(["extension", message]))
}

/// Sends the post initialization data to the server
pub fn a3_post_init(arma: &mut Arma, message: &Message) {
    let data = retrieve_data!(&message, PostInit);
    send_to_arma(
        "ESMs_system_process_postInit",
        arma_value!({
            "id": message.id,
            "data": arma_value!({
                "ESM_ServerID": arma.client.token().server_id(),
                "ESM_CommunityID": arma.client.token().community_id(),
                "ESM_ExtDBVersion": arma.database.extdb_version,
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
                "ESM_Taxes_TerritoryPayment": data.territory_payment_tax,
                "ESM_Taxes_TerritoryUpgrade": data.territory_upgrade_tax,
                "ESM_TerritoryAdminUIDs": data.territory_admins
            }),
            "metadata": message.metadata
        })
    );
}

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
// #[rv]
// pub fn next_chunk(string_id: String) -> String {
//     // Convert the ID to a UUID to ensure it's valid
//     let id = match Uuid::from_str(&string_id) {
//         Ok(id) => id,
//         Err(e) => {
//             let output = RVOutput::new(
//                 None,
//                 -1,
//                 arma_value!(format!("The provided UUID (\"{}\") is invalid. Reason: {}", string_id, e))
//             ).to_string();

//             debug!("[next_chunk] {:?}", output);
//             return output;
//         }
//     };

//     // Attempt to find the chunks associated to that ID
//     let mut chunk_writer = CHUNKS.write();
//     let chunks = match chunk_writer.get_mut(&string_id) {
//         Some(chunks) => chunks,
//         None => {
//             let output =  RVOutput::new(
//             None,
//             -1,
//             arma_value!(format!("The provided UUID (\"{}\") does not exist.", id))
//             ).to_string();

//             debug!("[next_chunk] {:?}", output);
//             return output;
//         }
//     };

//     // Ensure there is data to pull
//     let next_chunk = match chunks.pop() {
//         Some(chunk) => chunk,
//         None => {
//             let output = RVOutput::new(None, -1, arma_value!(format!("The provided UUID (\"{}\") has no more chunks.", id))).to_string();
//             debug!("[next_chunk] {:?}", output);
//             return output;
//         }
//     };

//     // Check to see if there are any chunks left and remove the ID if needed
//     let chunks_left = chunks.len();
//     let code = if chunks_left > 0 {
//         1
//     } else {
//         // It's the last chunk, remove it and let Arma know.
//         chunk_writer.remove(&string_id);

//         0
//     };

//     // Provide the chunk to Arma
//     let output = RVOutput::new(Some(id), code, arma_value!(next_chunk)).to_string();
//     debug!("[next_chunk] {}", output);
//     output
// }

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
    price_per_object: f32,
    territory_lifetime: f32,
    territory_data: String,
    vg_enabled: bool,
    vg_max_sizes: String,
) {
    // Only allow this method to be called properly once
    if *READY.read() {
        warn!("[#pre_init] This endpoint can only be called once. Perhaps your server is boot looping?");
        return;
    }

    info!("[#pre_init] ESM is booting");

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
    // debug!("[#event] ID: {:?}\nDATA: {:#?}\nMETADATA: {:#?}\nERRORS: {:#?}", id, data, metadata, errors);

    let message = match Message::from_arma(Type::Event, id, data, metadata, errors) {
        Ok(m) => m,
        Err(e) => return error!("[#event] {}", e)
    };

    let arma = crate::ARMA.read();
    arma.client.send_to_server(message);
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
