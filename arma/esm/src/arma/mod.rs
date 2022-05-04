pub mod data;

use data::Token;
use esm_message::{retrieve_data, Data, Message, Metadata};

use crate::client::Client;
use crate::database::Database;

pub struct Arma {
    pub client: Client,
    pub database: Database,
}

impl Arma {
    pub fn new(token: Token, initialization_data: Data) -> Self {
        let client = Client::new(token, initialization_data);
        let database = Database::new();

        Arma { client, database }
    }

    pub fn extdb_version(&self) -> u8 {
        self.database.extdb_version
    }

    pub fn post_initialization(&mut self, mut message: Message) -> Option<Message> {
        let data = retrieve_data!(message.data, Data::PostInit);

        // Get the base path to figure out where to look for the ini
        let base_ini_path = if data.extdb_path.is_empty() {
            String::from("@ExileServer")
        } else {
            data.extdb_path
        };

        // Connect to the database
        if self.database.connect(base_ini_path).is_err() {
            // This will tell the bot to log the error to the community's logging channel.
            message.add_error(
                esm_message::ErrorType::Code,
                String::from("fail_database_connect"),
            );

            return Some(message);
        }

        // Call arma
        crate::a3_post_init(self, &message);

        None
    }

    pub fn call_function(&self, mut message: Message) -> Option<Message> {
        let metadata = retrieve_data!(message.metadata, Metadata::Command);

        // First, check to make sure the player has joined this server
        if !self.database.account_exists(&metadata.player.steam_uid) {
            message.add_error(
                esm_message::ErrorType::Code,
                String::from("player_account_does_not_exist"),
            );
            return Some(message);
        }

        // If the command has a target, check to make sure they've joined the server
        if let Some(target_player) = &metadata.target {
            if !self.database.account_exists(&target_player.steam_uid) {
                message.add_error(
                    esm_message::ErrorType::Code,
                    String::from("target_account_does_not_exist"),
                );
                return Some(message);
            }
        }

        // Now process the message
        match message.data {
            Data::Reward(_) => crate::a3_call_function("ESMs_command_reward", &message),
            Data::Sqf(_) => crate::a3_call_function("ESMs_command_sqf", &message),
            _ => unreachable!("[arma::call_extension] This is a bug. Data type \"{:?}\" has not been implemented yet", message.data)
        }

        None
    }
}
