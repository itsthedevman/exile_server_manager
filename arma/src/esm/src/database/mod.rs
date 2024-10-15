mod queries;

use crate::*;

use ini::Ini;
pub use mysql_async::{
    params, prelude::Queryable, Conn, Opts, Params, Pool, Result as SQLResult,
};
use queries::Queries;
pub use serde::{Deserialize, Serialize};
pub use std::{collections::HashMap, path::Path};

import!(hasher);

pub type DatabaseResult = Result<Vec<String>, Error>;
pub type QueryResult = Result<Vec<String>, QueryError>;

#[derive(Clone)]
pub struct Database {
    pub extdb_version: u8,
    pub hasher: Hasher,
    connection_pool: Arc<Mutex<Option<Pool>>>,
    sql: Queries,
}

impl Default for Database {
    fn default() -> Database {
        let mod_name = crate::CONFIG.server_mod_name.clone();
        let extension = if cfg!(windows) { ".dll" } else { ".so" };
        let x86_default_path = format!("{mod_name}/extDB3{extension}");
        let x64_default_path = format!("{mod_name}/extDB3_x64{extension}");

        let extdb_version = if crate::CONFIG.extdb_version != 0 {
            crate::CONFIG.extdb_version
        } else if Path::new(&x86_default_path).exists()
            || Path::new(&x64_default_path).exists()
        {
            3
        } else {
            2
        };

        Database {
            extdb_version,
            connection_pool: Arc::new(Mutex::new(None)),
            hasher: Hasher::new(),
            sql: Queries::new(),
        }
    }
}

impl Database {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn connect(&self, base_ini_path: &str) -> ESMResult {
        self.sql.validate()?;

        // Build the connection URI
        let database_url = match connection_string(base_ini_path, self.extdb_version) {
            Ok(url) => url,
            Err(e) => return Err(format!("[connect] {}", e).into()),
        };

        // Convert it to options
        let database_opts = match Opts::from_url(&database_url) {
            Ok(opts) => opts,
            Err(e) => return Err(format!("[connect] {}", e).into()),
        };

        *await_lock!(self.connection_pool) = Some(Pool::new(database_opts));

        // Attempt to connect to the database
        if let Err(e) = self.connection().await {
            error!("{e}");

            return Err(format!(
                "[connect] Failed to connect to MySQL at {}",
                database_url
            )
            .into());
        };

        Ok(())
    }

    pub async fn connection(&self) -> Result<Conn, String> {
        match &*await_lock!(self.connection_pool) {
            Some(pool) => match pool.get_conn().await {
                Ok(c) => Ok(c),
                Err(e) => Err(format!("[connection] {}", e)),
            },
            None => {
                Err("[connection] Attempted to retrieve a connection from the pool before the pool was open for swimming.".into())
            }
        }
    }

    pub async fn query(
        &self,
        name: &str,
        arguments: HashMap<String, String>,
    ) -> DatabaseResult {
        let mut connection = self.connection().await?;

        // Need a better way of doing this...
        let query_result: QueryResult = match name {
            "reward_territories" => {
                queries::command_reward_territories(&self, &mut connection, &arguments)
                    .await
            }
            "me" => queries::command_me(&self, &mut connection, &arguments).await,
            "all_territories" => {
                queries::command_all_territories(&self, &mut connection, &arguments).await
            }
            "player_territories" => {
                queries::player_territories(&self, &mut connection, &arguments).await
            }
            "set_id" => queries::command_set_id(&self, &mut connection, &arguments).await,
            "restore" => {
                queries::command_restore(&self, &mut connection, &arguments).await
            }
            _ => {
                return Err(format!(
                    "[query] ❌ Unexpected query \"{}\" with arguments {:?}",
                    name, arguments
                )
                .into())
            }
        };

        match query_result {
            Ok(r) => Ok(r),
            Err(e) => match e {
                QueryError::System(e) => {
                    error!("[{name}] ❌ {e}");
                    Err("error".into())
                }
                QueryError::User(e) => Err(Error::message(e)),
                QueryError::Code(e) => Err(Error::code(e)),
            },
        }
    }

    /// Attempts to decode a hashed territory ID or custom ID
    /// Do not use if you already have access to the database and connection (i.e in query files)
    pub async fn decode_territory_id(&self, territory_id: &str) -> Result<u64, Error> {
        let mut connection = self.connection().await?;
        queries::decode_territory_id(&self, &mut connection, territory_id).await
    }

    pub async fn set_territory_payment_counter(
        &self,
        database_id: usize,
        counter_value: usize,
    ) -> Result<(), Error> {
        let mut connection = self.connection().await?;

        queries::set_territory_payment_counter(
            &self,
            &mut connection,
            database_id,
            counter_value,
        )
        .await
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
fn connection_string(base_ini_path: &str, extdb_version: u8) -> Result<String, String> {
    if !crate::CONFIG.database_uri.is_empty() {
        return Ok(crate::CONFIG.database_uri.clone());
    }

    // Get the path and load the ini file
    let ini_path = extdb_conf_path(base_ini_path);

    let db_ini = match Ini::load_from_file(&ini_path) {
        Ok(ini) => ini,
        Err(e) => return Err(format!("[connect] Failed to load ExtDB's conf file located at {ini_path}. If you have a custom file path, you may overwrite it by setting the \"extdb_conf_path\" configuration option in @ESM/config.yml. Failure reason: {e}"))
    };

    let filename = if extdb_version == 3 {
        "extdb3-conf.ini"
    } else {
        "extdb-conf.ini"
    };

    let database_name_key = if extdb_version == 3 {
        "Database"
    } else {
        "Name"
    };

    let header_name = crate::CONFIG.extdb_conf_header_name.clone();

    let Some(section) = db_ini.section(Some(header_name.clone())) else {
        return Err(format!("Could not find the [{}] section containing your database connection details in {}. If you have a custom name, you may overwrite it by setting the \"database_header_name\" configuration option in @ESM/config.yml.", header_name, filename));
    };

    let Some(ip) = section.get("IP") else {
        return Err(format!(
            "Failed to find \"IP\" entry under [{}] section in your {}",
            header_name, filename
        ));
    };

    let Some(port) = section.get("Port") else {
        return Err(format!(
            "Failed to find \"Port\" entry under [{}] section in your {}",
            header_name, filename
        ));
    };

    let Some(username) = section.get("Username") else {
        return Err(format!(
            "Failed to find \"Username\" entry under [{}] section in your {}",
            header_name, filename
        ));
    };

    let Some(password) = section.get("Password") else {
        return Err(format!(
            "Failed to find \"Password\" entry under [{}] section in your {}",
            header_name, filename
        ));
    };

    let Some(database_name) = section.get(database_name_key) else {
        return Err(format!(
            "Failed to find \"{}\" entry under [{}] section in your {}",
            database_name_key, header_name, filename
        ));
    };

    // mysql://user:password@host:port/database_name
    Ok(format!(
        "mysql://{}:{}@{}:{}/{}",
        username, password, ip, port, database_name
    ))
}

fn extdb_conf_path(base_ini_path: &str) -> String {
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

pub enum QueryError {
    System(String),
    User(String),
    Code(String),
}

impl From<Error> for QueryError {
    fn from(value: Error) -> Self {
        match value.error_type {
            ErrorType::Code => Self::Code(value.error_content),
            ErrorType::Message => Self::User(value.error_content),
        }
    }
}
