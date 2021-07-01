

use esm_message::Data;



use crate::client::Client;
use crate::{database::Database};


use super::data::Token;

pub struct Arma {
    client: Client,
    database: Database,
}

impl Arma {
    pub fn new(token: Token, initialization_data: Data) -> Self {
        let client = Client::new(token, initialization_data);
        let database = Database::new();

        Arma { client, database }
    }

    pub fn connect(&self) {
        self.client.connect()
    }

    // pub fn extdb_version(&self) -> u8 {
    //     self.database.extdb_version
    // }

    // pub fn server_initialization(&self, command: &Command) {
    //     match &self.server_initialization_package {
    //         Some(val) => {
    //             crate::BOT.send(Some(command.id.clone()), command.command_name.clone(), val.clone());
    //         }
    //         _ => {
    //             error!("[arma_server::server_initialization] Requested server initialization before anything has been stored. ESM_fnc_preInit must be called first.");
    //         },
    //     };
    // }

    // pub fn post_initialization(&mut self, command: &Command) {
    //     let parameters: &ServerPostInitialization = match command.parameters {
    //         Parameters::ServerPostInitialization(ref val) => val,
    //         _ => {
    //             error!("[arma_server::post_initialization] Failed to retrieve parameters. Parameters was parsed as {:?}", command.parameters);
    //             return;
    //         }
    //     };

    //     // Stores the server_id
    //     self.id = parameters.server_id.clone();

    //     // Stores the max_payment_count
    //     self.max_payment_count = parameters.max_payment_count;

    //     // Get the base path to figure out where to look for the ini
    //     let base_ini_path = if parameters.extdb_path.is_empty() { String::from("@ExileServer") } else { parameters.extdb_path.clone() };

    //     // Connect to the database
    //     self.database.connect(base_ini_path);

    //     crate::a3_post_server_initialization(command, parameters, self.extdb_version());
    // }

    // pub fn reward(&self, command: &Command) {
    //     let parameters = match command.parameters {
    //         Parameters::Reward(ref val) => val,
    //         _ => {
    //             return error!("[arma_server::reward] Failed to retrieve parameters. Parameters was parsed as {:?}", command.parameters);
    //         }
    //     };

    //     let metadata = match command.metadata {
    //         Metadata::Default(ref val) => val,
    //         _ => {
    //             return error!("[arma_server::reward] Failed to retrieve metadata. Metadata was parsed as {:?}", command.metadata);
    //         }
    //     };

    //     // Check to make sure the user who is executing this command has joined this server
    //     if !self.database.account_exists(&parameters.target_uid) {
    //         return command.reply_with_error_code("account_does_not_exist");
    //     }

    //     crate::a3_reward(&command, &parameters, &metadata);
    // }
}
