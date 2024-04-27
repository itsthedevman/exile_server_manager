use crate::*;
use ini::Ini;
use mysql_async::{params, prelude::Queryable, Conn, Opts, Params, Pool, Result as SQLResult};
use parking_lot::RwLock;
use serde::{Deserialize, Serialize};
use std::{collections::HashMap, path::Path};

type DatabaseResult = Result<QueryResult, Error>;

#[derive(Clone)]
pub struct Database {
    pub extdb_version: u8,
    pub hasher: Hasher,
    connection_pool: Arc<Mutex<Option<Pool>>>,
    statements: Statements,
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
            hasher: Hasher::new(),
            statements: Statements::new(),
        }
    }
}

impl Database {
    pub fn new() -> Self {
        Self::default()
    }

    pub async fn connect(&self, base_ini_path: &str) -> ESMResult {
        self.statements.validate()?;

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

    pub async fn decode_territory_id(&self, territory_id: &String) -> Result<u64, Error> {
        let mut connection = self.connection().await?;

        if let Some(id) = self.hasher.decode(&territory_id) {
            return Ok(id);
        }

        let result: SQLResult<Option<u64>> = connection
            .exec_first(
                &self.statements.decode_territory_id,
                params! { "territory_id" => territory_id },
            )
            .await;

        match result {
            Ok(r) => match r {
                Some(v) => Ok(v),
                None => Err(Error {
                    error_type: ErrorType::Code,
                    error_content: String::from("territory_id_does_not_exist"),
                }),
            },
            Err(e) => Err(e.to_string().into()),
        }
    }

    //////////////////////////////////////////////////////////////////////////////////////////////////
    /// Command related queries
    //////////////////////////////////////////////////////////////////////////////////////////////////

    pub async fn query(&self, name: &str, arguments: &HashMap<String, String>) -> DatabaseResult {
        let mut connection = self.connection().await?;

        let query_result = match name {
            "reward_territories" => {
                self.command_reward_territories(&mut connection, arguments)
                    .await
            }
            "me" => self.command_me(&mut connection, arguments).await,
            "all_territories" => {
                self.command_all_territories(&mut connection, arguments)
                    .await
            }
            _ => {
                return Err(format!(
                    "[query] ❌ Unexpected query \"{}\" with arguments {:?}",
                    name, arguments
                )
                .into())
            }
        };

        query_result
    }

    async fn command_reward_territories(
        &self,
        connection: &mut Conn,
        arguments: &HashMap<String, String>,
    ) -> DatabaseResult {
        let player_uid = match arguments.get("uid") {
            Some(uid) => uid,
            None => {
                error!(
                    "[query_reward_territories] ❌ Missing key `uid` in provided query arguments"
                );
                return Err("error".into());
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

                Ok(QueryResult { results })
            }
            Err(e) => {
                error!("[reward_territories] ❌ Query failed - {}", e);
                Err("error".into())
            }
        }
    }

    async fn command_me(
        &self,
        connection: &mut Conn,
        arguments: &HashMap<String, String>,
    ) -> DatabaseResult {
        let player_uid = match arguments.get("uid") {
            Some(uid) => uid,
            None => {
                error!("[query_me] ❌ Missing key `uid` in provided query arguments");
                return Err("error".into());
            }
        };

        #[derive(Debug, Deserialize, Serialize)]
        struct TerritoryResult {
            id: String,
            name: String,
        }

        #[derive(Debug, Serialize)]
        struct PlayerResult {
            locker: i32,
            score: i32,
            name: String,
            money: Option<i32>,
            damage: Option<f64>,
            hunger: Option<f64>,
            thirst: Option<f64>,
            kills: i32,
            deaths: i32,
            territories: Vec<TerritoryResult>,
        }

        let result = connection
            .exec_map(
                &self.statements.command_me,
                // The "uid" argument must be before "uid_wildcard" since it's a substring of the other
                params! { "uid_wildcard" => format!("%{}%", player_uid), "uid" => player_uid },
                |(
                    locker,
                    score,
                    name,
                    money,
                    damage,
                    hunger,
                    thirst,
                    kills,
                    deaths,
                    territories,
                )| {
                    let territories_json: Option<String> = territories;
                    let mut territories = vec![];

                    if let Some(territories_json) = territories_json {
                        if let Ok(territories_parsed) =
                            serde_json::from_str::<Vec<TerritoryResult>>(&territories_json)
                        {
                            territories_parsed.into_iter().for_each(|mut territory| {
                                territory.id = self.hasher.encode(territory.id);
                                territories.push(territory);
                            });
                        }
                    }

                    PlayerResult {
                        locker,
                        score,
                        name,
                        money,
                        damage,
                        hunger,
                        thirst,
                        kills,
                        deaths,
                        territories,
                    }
                },
            )
            .await;

        match result {
            Ok(players) => {
                let results: Vec<String> = players
                    .into_iter()
                    .map(|player| serde_json::to_string(&player).unwrap())
                    .collect();

                Ok(QueryResult { results })
            }
            Err(e) => {
                error!("[query_me] ❌ Query failed - {}", e);
                Err("error".into())
            }
        }
    }

    async fn command_all_territories(
        &self,
        connection: &mut Conn,
        _arguments: &HashMap<String, String>,
    ) -> DatabaseResult {
        #[derive(Debug, Serialize)]
        struct TerritoryResult {
            id: String,
            esm_custom_id: Option<String>,
            territory_name: String,
            owner_uid: String,
            owner_name: String,
        }

        let result = connection
            .exec_map(
                &self.statements.command_all_territories,
                Params::Empty,
                |(id, esm_custom_id, territory_name, owner_uid, owner_name)| TerritoryResult {
                    id: self.hasher.encode(id),
                    esm_custom_id,
                    territory_name,
                    owner_uid,
                    owner_name,
                },
            )
            .await;

        match result {
            Ok(r) => {
                let results: Vec<String> = r
                    .into_iter()
                    .filter_map(|t| serde_json::to_string(&t).ok())
                    .collect();

                Ok(QueryResult { results })
            }
            Err(e) => {
                error!("[query_me] ❌ Query failed - {}", e);
                Err("error".into())
            }
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

#[derive(Clone)]
pub struct Hasher {
    builder: Arc<RwLock<harsh::Harsh>>,
}

impl Hasher {
    const ALPHABET: &'static str = "abcdefghijklmnopqrstuvwxyz";
    const LENGTH: usize = 5;

    pub fn new() -> Self {
        Hasher {
            builder: Arc::new(RwLock::new(Self::builder(&random_bs_go!()))),
        }
    }

    fn builder(salt: &str) -> harsh::Harsh {
        harsh::Harsh::builder()
            .length(Hasher::LENGTH)
            .alphabet(Hasher::ALPHABET)
            .salt(salt)
            .build()
            .unwrap()
    }

    pub fn encode(&self, id: String) -> String {
        let Ok(id) = id.parse() else {
            return String::new();
        };

        self.builder.read().encode(&[id])
    }

    pub fn decode(&self, input: &str) -> Option<u64> {
        let Ok(numbers) = self.builder.read().decode(input) else {
            return None;
        };

        numbers.get(0).copied()
    }

    pub fn set_salt(&self, salt: &str) {
        *self.builder.write() = Self::builder(salt)
    }
}

#[derive(Clone, Debug, Default)]
struct Statements {
    decode_territory_id: String,

    // Command queries
    command_me: String,
    command_all_territories: String,
}

// I would much rather this to be a macro so I don't have to manually add
// all of this extra code
impl Statements {
    pub fn new() -> Self {
        Statements {
            decode_territory_id: include_sql!("decode_territory_id"),
            command_me: include_sql!("command_me"),
            command_all_territories: include_sql!("command_all_territories"),
        }
    }

    pub fn validate(&self) -> ESMResult {
        if self.decode_territory_id.is_empty() {
            return Self::format_error("decode_territory_id");
        }

        if self.command_me.is_empty() {
            return Self::format_error("command_me");
        }

        if self.command_all_territories.is_empty() {
            return Self::format_error("command_all_territories");
        }

        Ok(())
    }

    fn format_error(name: &str) -> ESMResult {
        Err(format!(
            "Failed to load {name}.sql. Please ensure @esm/sql/queries/{name}.sql exists and contains valid SQL"
        )
        .into())
    }
}

/*
{
    "list_territories",
    @"SELECT
        t.id as id,
        owner_uid,
        (SELECT name FROM account WHERE uid = owner_uid) as owner_name,
        name as territory_name,
        radius,
        level,
        flag_texture,
        flag_stolen,
        CONVERT_TZ(`last_paid_at`, @@session.time_zone, '+00:00') AS `last_paid_at`,
        build_rights,
        moderators,
        (SELECT COUNT(*) FROM construction WHERE territory_id = t.id) as object_count,
        esm_custom_id
    FROM
        territory t
    WHERE
        deleted_at IS NULL
    AND
        (owner_uid = @uid OR build_rights LIKE CONCAT('%', @uid, '%') OR moderators LIKE CONCAT('%', @uid, '%'))"
},
{
    "territory_info",
    @"SELECT
        t.id as id,
        owner_uid,
        (SELECT name FROM account WHERE uid = owner_uid) as owner_name,
        name as territory_name,
        radius,
        level,
        flag_texture,
        flag_stolen,
        CONVERT_TZ(`last_paid_at`, @@session.time_zone, '+00:00') AS `last_paid_at`,
        build_rights,
        moderators,
        (SELECT COUNT(*) FROM construction WHERE territory_id = t.id) as object_count,
        esm_custom_id
    FROM
        territory t
    WHERE
        t.id = @tid"
},
{
    "list_territories_all",
    "SELECT t.id, owner_uid, a.name as owner_name, t.name, esm_custom_id FROM territory t INNER JOIN account a ON a.uid = owner_uid ORDER BY t.name ASC"
},
{
    "get_name",
    "SELECT name FROM account WHERE uid = @uid"
},
{
    "player_info_account_only",
    @"SELECT
        a.locker,
        a.score,
        a.name,
        a.kills,
        a.deaths,
        (
            SELECT CONCAT("[", GROUP_CONCAT(JSON_OBJECT("id", id, "name", name) SEPARATOR ", "), "]")
            FROM territory
            WHERE deleted_at IS NULL AND (owner_uid = @uid OR build_rights LIKE CONCAT('%', @uid, '%') OR moderators LIKE CONCAT('%', @uid, '%'))
        ) as territories
    FROM account a
    WHERE
        a.uid = @uid"
},
{
    "leaderboard",
    "SELECT name FROM account ORDER BY kills DESC LIMIT 10"
},
{
    "leaderboard_deaths",
    "SELECT name FROM account ORDER BY deaths DESC LIMIT 10"
},
{
    "leaderboard_score",
    "SELECT name FROM account ORDER BY score DESC LIMIT 10"
},
{
    "restore",
    @"UPDATE territory SET deleted_at = NULL, xm8_protectionmoney_notified = 0, last_paid_at = NOW() WHERE id = @tid;
    UPDATE construction SET deleted_at = NULL WHERE id = @tid;
    UPDATE container SET deleted_at = NULL WHERE id = @tid;"
},
{
    "reset_player",
    "DELETE FROM player WHERE account_uid = @uid"
},
{
    "reset_all",
    "DELETE FROM player WHERE damage = 1"
},
{
    "get_territory_id_from_hash",
    "SELECT id FROM territory WHERE esm_custom_id = @tid"
},
{
    "set_custom_territory_id",
    "UPDATE territory SET esm_custom_id = @tid WHERE id = @id AND owner_uid = @uid"
},
{
    "get_hash_from_id",
    "SELECT esm_custom_id FROM territory WHERE id = @id"
},
{
    "get_payment_count",
    "SELECT esm_payment_counter FROM territory WHERE id = @id"
},
{
    "increment_payment_counter",
    "UPDATE territory SET esm_payment_counter = esm_payment_counter + 1 WHERE id = @id"
},
{
    "reset_payment_counter",
    "UPDATE territory SET esm_payment_counter = 0 WHERE (owner_uid = @uid OR build_rights LIKE CONCAT('%', @uid, '%') OR moderators LIKE CONCAT('%', @uid, '%'))"
}
 */
