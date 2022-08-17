use esm_message::{data, retrieve_data, Data, ErrorType, Message};
use ini::Ini;
use log::*;
use mysql::{params, prelude::Queryable, Opts, Pool, PooledConn, Result as QueryResult};
use serde::Serialize;
use std::{collections::HashMap, path::Path};

pub struct Database {
    pub extdb_version: u8,
    connection_pool: Option<Pool>,
}

impl Default for Database {
    fn default() -> Database {
        let extdb_version = if crate::CONFIG.extdb_version != 0 {
            crate::CONFIG.extdb_version
        } else if Path::new("@ExileServer/extDB3_x64.dll").exists() {
            3
        } else {
            2
        };

        Database {
            extdb_version,
            connection_pool: None,
        }
    }
}

// Unfortunately, due to the limitation with message-io, this cannot use an async ORM.
impl Database {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn connection(&self) -> Result<PooledConn, String> {
        match &self.connection_pool {
            Some(pool) => match pool.get_conn() {
                Ok(c) => Ok(c),
                Err(e) => Err(format!("[database::connection] {}", e)),
            },
            None => {
                Err("[database::connection] Attempted to retrieve a connection from the pool before the pool was open for swimming.".into())
            }
        }
    }

    pub fn connect(&mut self, base_ini_path: String) -> Result<(), ()> {
        // Get the path and load the ini file
        let ini_path = self.extdb_conf_path(base_ini_path);
        let db_ini = match Ini::load_from_file(&ini_path) {
            Ok(ini) => ini,
            Err(e) => {
                error!("[database::connect] Failed to load ExtDB's conf file located at {}. If you have a custom file path, you may overwrite it by setting the \"extdb_conf_path\" configuration option in @ESM/config.yml.", ini_path);
                debug!("[database::connect] Reason: {}", e);

                return Err(());
            }
        };

        // Build the connection URI
        let database_url = match self.connection_string(db_ini) {
            Ok(url) => url,
            Err(e) => {
                error!("[database::connection_string] {}", e);
                return Err(());
            }
        };

        // Convert it to options
        let database_opts = match Opts::from_url(&database_url) {
            Ok(opts) => opts,
            Err(e) => {
                error!("[database::connection_string] {}", e);
                return Err(());
            }
        };

        // Connect to the database!
        self.connection_pool = match Pool::new(database_opts) {
            Ok(pool) => Some(pool),
            Err(_e) => {
                error!("[database::connect] Failed to connect to MySQL.");
                debug!("[database::connect] URI: {}", database_url);
                return Err(());
            }
        };

        Ok(())
    }

    pub fn query(&self, mut message: Message) -> Option<Message> {
        let data = retrieve_data!(message.data, Data::Query);
        let name = data.name;
        let arguments = data.arguments;

        let message = match name.as_str() {
            "reward_territories" => self.reward_territories(message, arguments),
            _ => {
                error!(
                    "[database::query] Unexpected query \"{}\" with arguments {:?}",
                    name, arguments
                );
                message.add_error(
                    esm_message::ErrorType::Message,
                    format!(
                        "Unexpected query \"{}\" with arguments {:?}",
                        name, arguments
                    ),
                );

                message
            }
        };

        Some(message)
    }

    pub fn account_exists(&self, player_uid: &str) -> bool {
        let mut connection = match self.connection() {
            Ok(connection) => connection,
            Err(e) => {
                error!(
                    "[database::account_exists] Unable to obtain a open connection to the database. Reason: {}",
                    e
                );
                return false;
            }
        };

        let result: QueryResult<Option<String>> = connection.exec_first(
            "SELECT CASE WHEN EXISTS(SELECT uid FROM account WHERE uid = :uid) THEN 'true' ELSE 'false' END",
            params! { "uid" => player_uid }
        );

        match result {
            Ok(r) => match r {
                Some(v) => v == "true",
                None => false,
            },
            Err(e) => {
                error!("[database::account_exists] {}", e);
                false
            }
        }
    }

    pub fn reward_territories(
        &self,
        mut message: Message,
        arguments: HashMap<String, String>,
    ) -> Message {
        let mut connection = match self.connection() {
            Ok(connection) => connection,
            Err(e) => {
                error!(
                    "[database::reward_territories] Unable to obtain a open connection to the database. Reason: {}",
                    e
                );

                message.add_error(ErrorType::Code, "client_exception");
                return message;
            }
        };

        let player_uid = match arguments.get("uid") {
            Some(uid) => uid,
            None => {
                error!("[database::reward_territories] Missing key :uid in data arguments");
                message.add_error(ErrorType::Code, "client_exception");
                return message;
            }
        };

        #[derive(Debug, Serialize)]
        struct TerritoryResult {
            pub id: i32,
            pub custom_id: Option<String>,
            pub name: String,
            pub level: i32,
            pub vehicle_count: i32,
        }

        let result = connection.exec_map(
            r#"
                SELECT
                    t.id,
                    esm_custom_id,
                    name,
                    level,
                    (SELECT COUNT(*) FROM vehicle WHERE territory_id = t.id) as vehicle_count
                FROM
                    territory t
                WHERE
                    deleted_at IS NULL
                AND
                    (owner_uid = :uid
                        OR build_rights LIKE :uid_wildcard
                        OR moderators LIKE :uid_wildcard)
            "#,
            params! { "uid" => player_uid, "uid_wildcard" => format!("%{}%", player_uid) },
            |(id, custom_id, name, level, vehicle_count)| TerritoryResult {
                id,
                custom_id,
                name,
                level,
                vehicle_count,
            },
        );

        match result {
            Ok(territories) => {
                let results: Vec<String> = territories
                    .into_iter()
                    .map(|t| serde_json::to_string(&t).unwrap())
                    .collect();

                message.data = Data::QueryResult(data::QueryResult { results });
            }
            Err(e) => {
                error!("[database::reward_territories] {}", e);
                message.add_error(ErrorType::Code, "client_exception");
            }
        }

        message
    }

    /*
        ExtDB3
            [exile]
            IP = esm.mshome.net
            Port = 3306
            Username = root
            Password =  password12345
            Database = exile_test_esm

        ExtDB2
            [exile]
            Name = exile_test_esm
            Username = root
            Password = password12345
            IP = esm.mshome.net
            Port = 3306
    */
    fn connection_string(&self, db_ini: Ini) -> Result<String, String> {
        let filename = if self.extdb_version == 3 {
            "extdb3-conf.ini"
        } else {
            "extdb-conf.ini"
        };
        let database_name_key = if self.extdb_version == 3 {
            "Database"
        } else {
            "Name"
        };
        let header_name = crate::CONFIG.extdb_conf_header_name.clone();

        let section = match db_ini.section(Some(header_name.clone())) {
            Some(section) => section,
            None => {
                return Err(format!("Could not find the [{}] section containing your database connection details in {}. If you have a custom name, you may overwrite it by setting the \"database_header_name\" configuration option in @ESM/config.yml.", header_name, filename));
            }
        };

        let ip = match section.get("IP") {
            Some(ip) => ip,
            None => {
                return Err(format!(
                    "Failed to find \"IP\" entry under [{}] section in your {}",
                    header_name, filename
                ));
            }
        };

        let port = match section.get("Port") {
            Some(port) => port,
            None => {
                return Err(format!(
                    "Failed to find \"Port\" entry under [{}] section in your {}",
                    header_name, filename
                ));
            }
        };

        let username = match section.get("Username") {
            Some(username) => username,
            None => {
                return Err(format!(
                    "Failed to find \"Username\" entry under [{}] section in your {}",
                    header_name, filename
                ));
            }
        };

        let password = match section.get("Password") {
            Some(password) => password,
            None => {
                return Err(format!(
                    "Failed to find \"Password\" entry under [{}] section in your {}",
                    header_name, filename
                ));
            }
        };

        let database_name = match section.get(database_name_key) {
            Some(name) => name,
            None => {
                return Err(format!(
                    "Failed to find \"{}\" entry under [{}] section in your {}",
                    database_name_key, header_name, filename
                ));
            }
        };

        // mysql://user:password@host:port/database_name
        Ok(format!(
            "mysql://{}:{}@{}:{}/{}",
            username, password, ip, port, database_name
        ))
    }

    fn extdb_conf_path(&self, base_ini_path: String) -> String {
        if !crate::CONFIG.extdb_conf_path.is_empty() {
            return crate::CONFIG.extdb_conf_path.clone();
        }

        let file_path = format!("{}/extdb3-conf.ini", base_ini_path);
        let path = Path::new(&file_path);

        if path.exists() {
            // extDB3 is being used
            file_path
        } else {
            // extDB2 is being used
            format!("{}/extdb-conf.ini", base_ini_path)
        }
    }
}
