use std::{fs, process::Command};

use chrono::prelude::*;
use fake::{
    faker::{
        boolean::en::Boolean,
        chrono::en::DateTimeBetween,
        company::en::CompanyName,
        internet::en::Username,
        name::en::Name,
    },
    Fake,
};
use lazy_static::lazy_static;
use rand::seq::SliceRandom;
use std::fmt::Display;

use crate::{
    config::Config,
    context::BuildContext,
    error::{BuildError, BuildResult},
};

lazy_static! {
    static ref FLAG_TEXTURES: Vec<&'static str> = vec![
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_bis_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_vish_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_hollow_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_legion_ca.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_21dmd_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_spawny_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_secretone_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_stitchmoonz_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_commandermalc_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_jankon_co.paa",
        "\\\\A3\\\\Data_F\\\\Flags\\\\flag_blue_co.paa",
        "\\\\A3\\\\Data_F\\\\Flags\\\\flag_green_co.paa",
        "\\\\A3\\\\Data_F\\\\Flags\\\\flag_red_co.paa",
        "\\\\A3\\\\Data_F\\\\Flags\\\\flag_white_co.paa",
        "\\\\A3\\\\Data_F\\\\Flags\\\\flag_uk_co.paa",
    ];
}

pub fn seed_database(ctx: &mut BuildContext) -> BuildResult {
    let sql = generate_sql(&ctx.config);

    // Write SQL to a temp file on the host
    let sql_path = ctx.local_build_path.join("seed.sql");
    fs::write(&sql_path, &sql)?;

    // Parse credentials from mysql_uri: mysql://user:password@host:port/database
    let (user, password, _host_port, database) =
        parse_mysql_uri(&ctx.config.server.mysql_uri)?;

    // Copy SQL into the MySQL container, then execute it
    let container = "ESM_DB_MYSQL";
    let remote_sql = "/tmp/esm_seed.sql";

    let cp_output = Command::new("docker")
        .args([
            "compose",
            "cp",
            &sql_path.to_string_lossy().to_string(),
            &format!("mysql_db:{remote_sql}"),
        ])
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !cp_output.status.success() {
        let msg = String::from_utf8_lossy(&cp_output.stderr);
        return Err(BuildError::Docker(format!(
            "Failed to copy seed.sql into MySQL container: {}",
            msg.trim()
        )));
    }

    let exec_output = Command::new("docker")
        .args([
            "exec",
            "-t",
            container,
            "mysql",
            &format!("-u{user}"),
            &format!("-p{password}"),
            &database,
            "-e",
            &format!("source {remote_sql}"),
        ])
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !exec_output.status.success() {
        let err = String::from_utf8_lossy(&exec_output.stderr);
        return Err(BuildError::Docker(format!(
            "Database seed failed: {}", err.trim()
        )));
    }

    Ok(())
}

fn parse_mysql_uri(uri: &str) -> Result<(String, String, String, String), BuildError> {
    // mysql://user:password@host:port/database
    let without_scheme = uri
        .strip_prefix("mysql://")
        .ok_or_else(|| BuildError::Config(format!("Invalid mysql_uri: {uri}")))?;

    let (credentials, rest) = without_scheme.split_once('@').ok_or_else(|| {
        BuildError::Config(format!("Invalid mysql_uri (missing @): {uri}"))
    })?;

    let (user, password) = credentials.split_once(':').ok_or_else(|| {
        BuildError::Config(format!("Invalid mysql_uri (missing : in credentials): {uri}"))
    })?;

    let (host_port, database) = rest.split_once('/').ok_or_else(|| {
        BuildError::Config(format!("Invalid mysql_uri (missing /database): {uri}"))
    })?;

    Ok((
        user.to_string(),
        password.to_string(),
        host_port.to_string(),
        database.to_string(),
    ))
}

// ─── SQL generation ──────────────────────────────────────────────────────────

fn generate_sql(config: &Config) -> String {
    let mut steam_uids = config.steam_uids.clone();
    steam_uids.push(config.my_steam_uid.clone());

    let accounts = generate_accounts(&steam_uids);
    let players = generate_players(&accounts);
    let territories = generate_territories(&steam_uids);
    let constructions = generate_constructions(&territories);

    format!(
        r#"
DELETE FROM account;
DELETE FROM player;
DELETE FROM construction;
DELETE FROM container;
DELETE FROM territory;

INSERT INTO account
VALUES {accounts};

INSERT INTO player
VALUES {players};

INSERT INTO territory
VALUES {territories};

INSERT INTO construction
VALUES {constructions};
        "#,
        accounts = map_to_string(accounts),
        players = map_to_string(players),
        territories = map_to_string(territories),
        constructions = map_to_string(constructions),
    )
}

fn map_to_string<T: ToString>(vec: Vec<T>) -> String {
    vec.iter()
        .map(|x| x.to_string())
        .collect::<Vec<_>>()
        .join(",\n")
}

fn random_timestamp() -> String {
    let current = Local::now();
    let end = current.with_month(12).unwrap().with_day(31).unwrap();
    let random: DateTime<Utc> =
        DateTimeBetween(current.with_timezone(&Utc), end.with_timezone(&Utc)).fake();
    random.with_timezone(&Local).format("'%Y-%m-%d %H:%M:%S'").to_string()
}

fn generate_accounts(steam_uids: &[String]) -> Vec<Account> {
    steam_uids
        .iter()
        .map(|uid| Account {
            uid: uid.clone(),
            name: Name().fake::<String>().replace('\'', ""),
            score: (10_000..9_000_000).fake(),
            kills: (0..1000).fake(),
            deaths: (0..1000).fake(),
            locker: (10_000..9_000_000).fake(),
            total_connections: (0..50_000).fake(),
        })
        .collect()
}

fn generate_players(accounts: &[Account]) -> Vec<Player> {
    accounts
        .iter()
        .enumerate()
        .map(|(i, a)| Player {
            id: i + 1,
            name: a.name.clone(),
            account_uid: a.uid.clone(),
            money: (10_000..9_000_000).fake(),
            damage: (0.0..0.9).fake(),
            hunger: (0..100).fake(),
            thirst: (0..100).fake(),
            alcohol: (0..=5).fake(),
            temperature: (34..=37).fake(),
            wetness: (0.0..=1.0).fake(),
            oxygen_remaining: (0.4..1.0).fake(),
            bleeding_remaining: (0.0..1.0).fake(),
        })
        .collect()
}

fn generate_territories(steam_uids: &[String]) -> Vec<Territory> {
    let rng = &mut rand::thread_rng();
    let n = 5;

    steam_uids
        .iter()
        .enumerate()
        .map(|(i, owner)| {
            let mut build_rights: Vec<String> =
                steam_uids.choose_multiple(rng, n).cloned().collect();
            build_rights.push(owner.clone());
            build_rights.dedup();

            let mut moderators: Vec<String> =
                build_rights.choose_multiple(rng, n).cloned().collect();
            moderators.push(owner.clone());
            moderators.dedup();

            let stolen: bool = Boolean(50).fake();
            Territory {
                id: i + 1,
                esm_custom_id: if Boolean(50).fake() {
                    format!("'{}'", Username().fake::<String>().replace('\'', ""))
                } else {
                    "NULL".into()
                },
                owner_uid: owner.clone(),
                name: CompanyName().fake::<String>().replace('\'', ""),
                position_x: (0.0..5000.0).fake(),
                position_y: (0.0..5000.0).fake(),
                position_z: (0.0..20.0).fake(),
                radius: (0.0..100.0).fake(),
                level: (0..7).fake(),
                flag_texture: FLAG_TEXTURES.choose(rng).unwrap().to_string(),
                flag_stolen: u8::from(stolen),
                flag_stolen_by_uid: if stolen {
                    format!("'{}'", steam_uids.choose(rng).unwrap())
                } else {
                    "NULL".into()
                },
                flag_stolen_at: if stolen { random_timestamp() } else { "NULL".into() },
                xm8_protectionmoney_notified: 0,
                build_rights: format!("{build_rights:?}"),
                moderators: format!("{moderators:?}"),
            }
        })
        .collect()
}

fn generate_constructions(territories: &[Territory]) -> Vec<Construction> {
    territories
        .iter()
        .enumerate()
        .map(|(i, t)| Construction {
            id: i + 1,
            account_uid: t.owner_uid.clone(),
            spawned_at: random_timestamp(),
            position_x: t.position_x,
            position_y: t.position_y,
            position_z: t.position_z,
            is_locked: 0,
            territory_id: t.id,
        })
        .collect()
}

// ─── Domain structs ──────────────────────────────────────────────────────────

struct Account {
    uid: String, name: String, score: isize, kills: usize,
    deaths: usize, locker: isize, total_connections: usize,
}

impl Display for Account {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "('{uid}',{clan},'{name}',{score},{kills},{deaths},{locker},{first},{last_c},{last_d},'{total}')",
            uid = self.uid, clan = "NULL", name = self.name,
            score = self.score, kills = self.kills, deaths = self.deaths,
            locker = self.locker, first = random_timestamp(),
            last_c = "NOW()", last_d = random_timestamp(),
            total = self.total_connections,
        )
    }
}

struct Player {
    id: usize, name: String, account_uid: String, money: usize,
    damage: f64, hunger: usize, thirst: usize, alcohol: usize,
    temperature: usize, wetness: f64, oxygen_remaining: f64,
    bleeding_remaining: f64,
}

impl Display for Player {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({id},'{name}','{uid}',{money},{damage},{hunger},{thirst},{alcohol},{temp},{wetness},{oxygen},{bleeding},'{hitpoints}',{dir},{px},{py},{pz},{spawned},'{assigned}','{bp}','[]','[]','[]','','','[]','','','','[]','','[\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\"]','','[\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\\\"\"]','','[]','[]','[]','','[]','[]','[]',{updated})",
            id = self.id, name = self.name, uid = self.account_uid,
            money = self.money, damage = self.damage, hunger = self.hunger,
            thirst = self.thirst, alcohol = self.alcohol, temp = self.temperature,
            wetness = self.wetness, oxygen = self.oxygen_remaining,
            bleeding = self.bleeding_remaining,
            hitpoints = "[[\"face_hub\",0],[\"neck\",0],[\"head\",0],[\"pelvis\",0],[\"spine1\",0],[\"spine2\",0],[\"spine3\",0],[\"body\",0],[\"arms\",0],[\"hands\",0],[\"legs\",0],[\"body\",0]]",
            dir = 0, px = 9157, py = 10005, pz = 0,
            spawned = random_timestamp(),
            assigned = "[\"ItemMap\",\"ItemCompass\",\"Exile_Item_XM8\",\"ItemRadio\"]",
            bp = "B_Carryall_oli",
            updated = random_timestamp(),
        )
    }
}

struct Territory {
    id: usize, esm_custom_id: String, owner_uid: String, name: String,
    position_x: f64, position_y: f64, position_z: f64, radius: f64,
    level: isize, flag_texture: String, flag_stolen: u8,
    flag_stolen_by_uid: String, flag_stolen_at: String,
    xm8_protectionmoney_notified: u8, build_rights: String, moderators: String,
}

impl Display for Territory {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({id},{custom_id},'{owner}','{name}',{px},{py},{pz},{radius},{level},'{texture}',{stolen},{stolen_by},{stolen_at},{created},{paid},{notified},'{rights}','{mods}',{counter},{deleted})",
            id = self.id, custom_id = self.esm_custom_id, owner = self.owner_uid,
            name = self.name, px = self.position_x, py = self.position_y,
            pz = self.position_z, radius = self.radius, level = self.level,
            texture = self.flag_texture, stolen = self.flag_stolen,
            stolen_by = self.flag_stolen_by_uid, stolen_at = self.flag_stolen_at,
            created = random_timestamp(), paid = "NOW()",
            notified = self.xm8_protectionmoney_notified,
            rights = self.build_rights, mods = self.moderators,
            counter = 0, deleted = "NULL",
        )
    }
}

struct Construction {
    id: usize, account_uid: String, spawned_at: String,
    position_x: f64, position_y: f64, position_z: f64,
    is_locked: u8, territory_id: usize,
}

impl Display for Construction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({id},'Exile_Construction_WoodWall_Static','{uid}',{spawned},{px},{py},{pz},0,0,0,0,0,1,{locked},'000000',0,{territory},{updated},{deleted})",
            id = self.id, uid = self.account_uid, spawned = self.spawned_at,
            px = self.position_x, py = self.position_y, pz = self.position_z,
            locked = self.is_locked, territory = self.territory_id,
            updated = "NOW()", deleted = "NULL",
        )
    }
}
