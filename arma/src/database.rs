use crate::models::*;
use anyhow::{bail, Error};
use diesel::{
    expression::dsl::exists,
    prelude::*,
    r2d2::{self, ConnectionManager, PooledConnection},
    select, MysqlConnection,
};
use ini::Ini;
use log::*;
use std::path::Path;

pub type Pool = r2d2::Pool<ConnectionManager<MysqlConnection>>;
pub type Connection = PooledConnection<ConnectionManager<MysqlConnection>>;

pub struct Database {
    pub extdb_version: u8,
    connection_pool: Option<Pool>,
}

impl Database {
    pub fn new() -> Database {
        Database {
            extdb_version: 2,
            connection_pool: None,
        }
    }

    ///    let connection = self.database.connection(); // Result<Connection, Error>
    ///    let results = territory.load::<Territory>(&*connection); // QueryResult<Vec<Territory>>
    pub fn connection(&self) -> Result<Connection, Error> {
        match &self.connection_pool {
            Some(c) => match c.clone().get() {
                Ok(c) => Ok(c),
                Err(e) => bail!("[database::connection] {}", e),
            },
            None => {
                bail!("[database::connection] Attempted to retrieve a connection from the pool before the pool was open for swimming.");
            }
        }
    }

    pub fn connect(&mut self, base_ini_path: String) {
        let mut db_version = 2;

        let extdb3_ini_path = format!("{}/extdb3-conf.ini", base_ini_path);
        let extdb3_ini_path = Path::new(&extdb3_ini_path);

        let db_ini = if extdb3_ini_path.exists() {
            // We're using extDB3
            db_version = 3;

            Ini::load_from_file(extdb3_ini_path).unwrap()
        } else {
            match Ini::load_from_file(format!("{}/extdb-conf.ini", base_ini_path)) {
                Ok(ini) => ini,
                Err(_e) => match crate::CONFIG[0]["extdb_file_path"].as_str() {
                    Some(path) => match Ini::load_from_file(&path) {
                        Ok(ini) => ini,
                        Err(e) => {
                            return error!("[database::connect] Failed to find config for extDB. extdb_file_path is set as {}. Error: {}", path, e);
                        }
                    },
                    None => {
                        return error!("[database::connect] Failed to find config for extDB. Search for {}/extdb3-conf.ini and {}/extdb-conf.ini.", base_ini_path, base_ini_path);
                    }
                },
            }
        };

        // Stores the extdb_version
        self.extdb_version = db_version;

        let database_url = match self.connection_string(db_ini, db_version) {
            Ok(url) => url,
            Err(e) => {
                return error!("[database::connection_string] {}", e);
            }
        };

        let manager = ConnectionManager::<MysqlConnection>::new(&database_url);
        self.connection_pool = match r2d2::Pool::builder().build(manager) {
            Ok(pool) => Some(pool),
            Err(e) => {
                return error!(
                    "[database::connect] Failed to build connection pool for MySQL. Reason: {}",
                    e
                );
            }
        };
    }

    pub fn account_exists(&self, player_uid: &String) -> bool {
        use crate::schema::account::dsl::*;

        let connection = match self.connection() {
            Ok(connection) => connection,
            Err(e) => {
                error!(
                    "[database::account_exists] Unable to obtain a open connection to the database. Reason: {}",
                    e
                );
                return false;
            }
        };

        select(exists(account.filter(uid.eq(player_uid))))
            .get_result::<bool>(&*connection)
            .unwrap_or(false)
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
    fn connection_string(&self, db_ini: Ini, db_version: u8) -> Result<String, String> {
        let filename = if db_version == 3 {
            "extdb3-conf.ini"
        } else {
            "extdb-conf.ini"
        };
        let database_name_key = if db_version == 3 { "Database" } else { "Name" };

        let header_name = match crate::CONFIG[0]["database_header_name"].as_str() {
            Some(name) => name,
            None => "exile",
        };

        let section = match db_ini.section(Some(header_name)) {
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

        // mysql://[[user]:[password]@]host[:port][/database][?unix_socket=socket-path]
        Ok(format!(
            "mysql://{}:{}@{}:{}/{}",
            username, password, ip, port, database_name
        ))
    }
}
