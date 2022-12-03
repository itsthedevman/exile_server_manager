use crate::*;
use ini::Ini;
use mysql_async::{params, prelude::Queryable, Conn, Opts, Pool, Result as QueryResult};
use serde::Serialize;
use std::{collections::HashMap, path::Path};

#[derive(Clone)]
pub struct Database {
    pub extdb_version: u8,
    connection_pool: Arc<Mutex<Option<Pool>>>,
}

impl Default for Database {
    fn default() -> Database {
        let mod_name = crate::CONFIG.server_mod_name.clone();
        let extension = if cfg!(windows) { ".dll" } else { ".so" };
        let x86_default_path = format!("{mod_name}/extDB3{extension}");
        let x64_default_path = format!("{mod_name}/extDB3_x64{extension}");

        let extdb_version = if crate::CONFIG.extdb_version != 0 {
            crate::CONFIG.extdb_version
        } else if Path::new(&x86_default_path).exists() || Path::new(&x64_default_path).exists() {
            3
        } else {
            2
        };

        Database {
            extdb_version,
            connection_pool: Arc::new(Mutex::new(None)),
        }
    }
}

// Unfortunately, due to the limitation with message-io, this cannot use an async ORM.
impl Database {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn connect(&self, base_ini_path: &str) -> ESMResult {
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

            return Err(format!("[connect] Failed to connect to MySQL at {}", database_url).into());
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

    pub async fn query(&self, message: Message) -> MessageResult {
        let data = retrieve_data!(message.data, Data::Query);
        let name = data.name;
        let arguments = data.arguments;

        match name.as_str() {
            "reward_territories" => self.reward_territories(message, arguments).await,
            _ => Err(format!(
                "[query] Unexpected query \"{}\" with arguments {:?}",
                name, arguments
            )
            .into()),
        }
    }

    pub async fn account_exists(&self, player_uid: &str) -> Result<bool, ESMError> {
        let mut connection = self.connection().await?;

        let result: QueryResult<Option<String>> = connection.exec_first(
            "SELECT CASE WHEN EXISTS(SELECT uid FROM account WHERE uid = :uid) THEN 'true' ELSE 'false' END",
            params! { "uid" => player_uid }
        ).await;

        match result {
            Ok(r) => match r {
                Some(v) => Ok(v == "true"),
                None => Ok(false),
            },
            Err(e) => Err(format!("[account_exists] {e}").into()),
        }
    }

    pub async fn reward_territories(
        &self,
        message: Message,
        arguments: HashMap<String, String>,
    ) -> MessageResult {
        let mut connection = self.connection().await?;

        let player_uid = match arguments.get("uid") {
            Some(uid) => uid,
            None => return Err("[reward_territories] ❌ Missing key :uid in data arguments".into()),
        };

        #[derive(Debug, Serialize)]
        struct TerritoryResult {
            pub id: i32,
            pub custom_id: Option<String>,
            pub name: String,
            pub level: i32,
            pub vehicle_count: i32,
        }

        let result = connection
            .exec_map(
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
            )
            .await;

        match result {
            Ok(territories) => {
                let results: Vec<String> = territories
                    .into_iter()
                    .map(|t| serde_json::to_string(&t).unwrap())
                    .collect();

                Ok(Some(message.set_data(Data::QueryResult(
                    data::QueryResult { results },
                ))))
            }
            Err(e) => Err(format!("[reward_territories] ❌ {}", e).into()),
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
