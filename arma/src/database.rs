use crate::models::*;
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

impl Default for Database {
    fn default() -> Database {
        let extdb_version = if crate::CONFIG.extdb_version != 0 {
            crate::CONFIG.extdb_version
        } else if Path::new("@ExileServer/extDB3_x64.dll").exists() {
            3
        } else {
            2
        };

        Database { extdb_version, connection_pool: None, }
    }
}

impl Database {
    pub fn new() -> Self {
        Self::default()
    }

    ///    let connection = self.database.connection(); // Result<Connection, String>
    ///    let results = territory.load::<Territory>(&*connection); // QueryResult<Vec<Territory>>
    pub fn connection(&self) -> Result<Connection, String> {
        match &self.connection_pool {
            Some(c) => match c.clone().get() {
                Ok(c) => Ok(c),
                Err(e) => Err(format!("[database::connection] {}", e)),
            },
            None => {
                Err("[database::connection] Attempted to retrieve a connection from the pool before the pool was open for swimming.".into())
            }
        }
    }

    pub fn connect(&mut self, base_ini_path: &String) -> Result<(), ()> {
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

        // Connect to the database!
        let manager = ConnectionManager::<MysqlConnection>::new(&database_url);
        self.connection_pool = match r2d2::Pool::builder().build(manager) {
            Ok(pool) => Some(pool),
            Err(e) => {
                error!("[database::connect] Failed to connect to MySQL.");
                debug!("[database::connect] URI: {}", database_url);
                return Err(());
            }
        };

        Ok(())
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
    fn connection_string(&self, db_ini: Ini) -> Result<String, String> {
        let filename = if self.extdb_version == 3 { "extdb3-conf.ini" } else { "extdb-conf.ini" };
        let database_name_key = if self.extdb_version == 3 { "Database" } else { "Name" };
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

    fn extdb_conf_path(&self, base_ini_path: &String) -> String {
        if !crate::CONFIG.extdb_conf_path.is_empty() { return crate::CONFIG.extdb_conf_path.clone(); }

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
