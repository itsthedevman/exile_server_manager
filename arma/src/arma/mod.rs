pub mod data;

use data::Token;
use esm_message::{Data, Message, retrieve_data};

use crate::client::Client;
use crate::{database::Database};

type EmptyResult = Result<(), ()>;

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

    pub fn post_initialization(&mut self, message: &mut Message) -> EmptyResult {
        let data = retrieve_data!(&message, PostInit);

        // Get the base path to figure out where to look for the ini
        let base_ini_path = if data.extdb_path.is_empty() { String::from("@ExileServer") } else { data.extdb_path.clone() };

        // Connect to the database
        if self.database.connect(&base_ini_path).is_err() {
            // This will tell the bot to log the error to the community's logging channel.
            message.add_error(esm_message::ErrorType::Code, "fail_database_connect");

            // Tell the caller that we had an uh-oh
            return Err(());
        }

        crate::a3_post_init(self, message);

        Ok(())
    }

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
