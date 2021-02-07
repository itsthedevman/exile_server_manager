

use ini::Ini;
use log::*;
use std::{path::Path, sync::RwLock};
use diesel::{MysqlConnection, r2d2::{self, ConnectionManager}};

pub type Pool = r2d2::Pool<ConnectionManager<MysqlConnection>>;

pub struct Database {
    pub extdb_version: RwLock<u8>,
    connection_pool: RwLock<Option<Pool>>,
}

impl Database {
    pub fn new() -> Database {
        Database {
            extdb_version: RwLock::new(2),
            connection_pool: RwLock::new(None),
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
        match self.extdb_version.try_write() {
            Ok(mut version) => {
                *version = db_version;
            }
            Err(e) => {
                warn!("[database::connect] Failed to gain write lock for max_payment_count attribute. Reason: {:?}", e);
            }
        }

        let database_url =
            match self.connection_string(db_ini, db_version) {
                Ok(url) => url,
                Err(e) => {
                    return error!("[database::connection_string] {}", e);
                }
            };

        let manager = ConnectionManager::<MysqlConnection>::new(&database_url);
        let pool = match r2d2::Pool::builder().build(manager) {
            Ok(pool) => pool,
            Err(e) => {
                return error!("[database::connect] Failed to build connection pool for MySQL. Reason: {}", e);
            }
        };

        // Stores the connection object for later use
        match self.connection_pool.try_write() {
            Ok(mut p) => {
                *p = Some(pool);
            }
            Err(e) => {
                warn!("[database::connect] Failed to gain write lock for max_payment_count attribute. Reason: {:?}", e);
            }
        }
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
        Ok(format!("mysql://{}:{}@{}:{}/{}", username, password, ip, port, database_name))
    }
}
