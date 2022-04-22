#[macro_use]
extern crate log;

mod arma;
mod client;
mod config;
mod database;

// Various Packages
use arma_rs::{arma, Context, Extension, IntoArma, Value};
use chrono::prelude::*;
use esm_message::*;
use lazy_static::lazy_static;
use serde::Serialize;
use serde_json::json;
use std::fmt::Debug;
use std::fs::File;
use std::io::Read;
use std::{env, fs};
use uuid::Uuid;

use parking_lot::RwLock;

// Logging
use log4rs::append::console::ConsoleAppender;
use log4rs::append::file::FileAppender;
use log4rs::config::{Appender, Config as LogConfig, Root};
use log4rs::encode::pattern::PatternEncoder;

use crate::arma::data::Token;
use crate::arma::Arma;
use crate::config::Config;

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

    /// Our connection to the arma server
    pub static ref CALLBACK: RwLock<Option<Context>> = RwLock::new(None);
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

    match log4rs::init_config(config) {
        Ok(_) => (),
        Err(_e) => println!("Failed to initialize logger"),
    };

    info!(
        "\n----------------------------------\nWelcome to Exile Server Manager v{} Build {}\nLoaded config {:#?}\n----------------------------------",
        env!("CARGO_PKG_VERSION"),
        env!("VERGEN_GIT_SHA_SHORT"),
        crate::CONFIG.to_hashmap()
    );
}

/// Loads the esm.key file from the disk and converts it to a Token
pub fn load_key() -> Option<Token> {
    let path = match env::current_dir() {
        Ok(mut p) => {
            p.push("@esm");
            p.push("esm.key");
            p
        }
        Err(e) => {
            error!("[#load_key] Failed to get current directory. Reason: {e}");
            return None;
        }
    };

    let mut file = match File::open(&path) {
        Ok(file) => file,
        Err(_) => {
            error!("[#load_key] Failed to find \"esm.key\" file here: {path:?}. If you haven't registered your server yet, please visit https://esmbot.com/wiki, click \"I am a Server Owner\", and follow the steps.");
            return None;
        }
    };

    let mut key_contents = Vec::new();
    match file.read_to_end(&mut key_contents) {
        Ok(_) => {
            trace!(
                "[#load_key] esm.key - {}",
                String::from_utf8_lossy(&key_contents)
            );
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
fn send_to_arma<D: Serialize + IntoArma + Debug>(
    function: &str,
    id: &Uuid,
    data: &D,
    metadata: &Metadata,
) {
    trace!(
        r#"[#send_to_arma]
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

    if env::var("ESM_IS_TERMINAL").is_ok() {
        return;
    }

    // Arma-rs converts hashes to [["key", "value"], ["key", "value"]], which is slower for the rv engine.
    // This is syntax #2, [["key", "key"], ["value", "value"]]
    let message = json!([
        json!(["id", "data", "metadata"]),
        json!([id.to_string(), data, metadata])
    ]);

    let callback = CALLBACK.read();
    match &*callback {
        Some(ctx) => ctx.callback("exile_server_manager", function, Some(message)),
        None => error!("[send_to_arma] Attempted to send a message to Arma but we haven't connected to Arma yet")
    }
}

/// Sends the post initialization data to the server
pub fn a3_post_init(arma: &mut Arma, message: &Message) {
    let data = retrieve_data!(message.data, Data::PostInit);
    let token = arma.client.token.read();

    send_to_arma(
        "ESMs_system_process_postInit",
        &message.id,
        &json!({
            "ESM_BuildNumber": env!("VERGEN_GIT_SHA_SHORT"),
            "ESM_CommunityID": token.community_id(),
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
            "ESM_LoggingChannelID": data.logging_channel_id,
            "ESM_ServerID": token.server_id(),
            "ESM_Taxes_TerritoryPayment": data.territory_payment_tax,
            "ESM_Taxes_TerritoryUpgrade": data.territory_upgrade_tax,
            "ESM_TerritoryAdminUIDs": data.territory_admins,
            "ESM_Version": env!("CARGO_PKG_VERSION")
        }),
        &message.metadata,
    );
}

pub fn a3_call_function(function_name: &str, message: &Message) {
    send_to_arma(function_name, &message.id, &message.data, &message.metadata);
}

///////////////////////////////////////////////////////////////////////
// Below are the Arma Functions accessible from callExtension
///////////////////////////////////////////////////////////////////////
/// Returns a UTC timestamp as a string.
pub fn utc_timestamp() -> String {
    Utc::now().to_rfc3339()
}

pub fn log_level() -> String {
    CONFIG.log_level.to_lowercase()
}

pub fn pre_init(
    ctx: Context,
    server_name: String,
    price_per_object: NumberString,
    territory_lifetime: NumberString,
    territory_data: String,
    vg_enabled: bool,
    vg_max_sizes: String,
) {
    trace!(
        r#"[#pre_init]
            server_name: {:?}
            price_per_object: {:?}
            territory_lifetime: {:?}
            territory_data: {:?}
            vg_enabled: {:?}
            vg_max_sizes: {:?}
        "#,
        server_name,
        price_per_object,
        territory_lifetime,
        territory_data,
        vg_enabled,
        vg_max_sizes
    );

    // Only allow this method to be called properly once
    if *READY.read() {
        warn!("[#pre_init] This endpoint can only be called once. Perhaps your server is boot looping?");
        return;
    }

    info!("[#pre_init] ESM is booting - Hello world!");

    // Load and convert the esm.key file into a token
    let token = match load_key() {
        Some(t) => t,
        None => return,
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
        extension_version: format!(
            "{}+{}",
            env!("CARGO_PKG_VERSION"),
            env!("VERGEN_GIT_SHA_SHORT")
        ),
    };

    trace!("[#pre_init] Initialization Data - {:?}", data);

    let arma = Arma::new(token, Data::Init(data));
    arma.client.connect();

    *ARMA.write() = arma;
    *CALLBACK.write() = Some(ctx);

    info!("[#pre_init] Boot completed");
}

pub fn send_message(
    id: String,
    message_type: String,
    data: String,
    metadata: String,
    errors: String,
) {
    debug!(
        "[#send_message]\nid: {:?}\ntype: {:?}\ndata: {:?}\nmetadata: {:?}\nerrors: {:?}",
        id, message_type, data, metadata, errors
    );

    let message = match Message::from_arma(id, message_type, data, metadata, errors) {
        Ok(m) => m,
        Err(e) => return error!("[#send_message] {}", e),
    };

    crate::ARMA.read().client.send_to_server(message);
}

pub fn send_to_channel(id: String, content: String) {
    trace!("[#send_to_channel]\nid: {:?}\ncontent: {:?}", id, content);

    let mut message = Message::new(Type::Event);
    message.data = Data::SendToChannel(data::SendToChannel { id, content });

    crate::ARMA.read().client.send_to_server(message);
}

#[arma]
pub fn init() -> Extension {
    // Initialize the static instances to start everything
    lazy_static::initialize(&CONFIG);
    lazy_static::initialize(&READY);
    lazy_static::initialize(&ARMA);

    // Start the logger
    initialize_logger();

    Extension::build()
        .command("utc_timestamp", utc_timestamp)
        .command("log_level", log_level)
        .command("pre_init", pre_init)
        .command("send_message", send_message)
        .command("send_to_channel", send_to_channel)
        .finish()
}

#[cfg(test)]
mod tests {
    use super::init;
    use regex::Regex;

    #[test]
    fn it_returns_current_timestamp() {
        let extension = init().testing();
        let (result, _) = unsafe { extension.call("utc_timestamp", None) };

        // "2021-01-01T00:00:00.000000000+00:00"
        let re =
            Regex::new(r#"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{9}\+\d{2}:\d{2}$"#).unwrap();

        assert!(re.is_match(&result));
    }

    #[test]
    fn it_returns_log_level() {
        let extension = init().testing();
        let (result, _) = unsafe { extension.call("log_level", None) };
        assert_eq!(result, "info");
    }
}
