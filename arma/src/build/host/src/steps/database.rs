use std::{collections::HashSet, fs, process::Command};

use chrono::{prelude::*, Duration};
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
use rand::{seq::{IndexedRandom, SliceRandom}, Rng, RngExt};
use std::fmt::Display;

use crate::{
    config::Config,
    context::InstanceContext,
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

// How many fake players to seed alongside my_steam_uid. Replaces the old
// hand-maintained steam_uids list in config.yml.
const STEAM_UID_COUNT: usize = 500;

// How many of those accounts are left connected. The player listing splits online from offline, so a run needs
// enough of both to fill pages on either side of the split.
const MIN_ONLINE: usize = 5;
const MAX_ONLINE: usize = 64;

const MINUTES_PER_DAY: i64 = 24 * 60;

/// Container running the shared MySQL server, from the root docker-compose stack.
const MYSQL_CONTAINER: &str = "ESM_DB_MYSQL";

/// Create this server's Exile database and build its schema if it is new.
///
/// Two sources make up a complete schema. `exile.sql` is Exile's own dump, which opens by dropping and
/// recreating a hardcoded database name; naming that database per server lets the script do the right thing
/// on its own. On top of it go ESM's own changes from `src/@esm/sql`, the same files `bin/db_migrate` applies,
/// without which the seed fails on a territory column and a missing table.
///
/// The only judgement here is whether to run at all: an existing database keeps its data, a new one is built
/// from scratch. That also means resetting a server no longer means deleting the whole MySQL volume.
pub fn ensure_database(ictx: &InstanceContext) -> BuildResult {
    let (user, password, _host_port) = parse_mysql_uri(&ictx.config().server.mysql_uri)?;
    let database = &ictx.instance.database;

    if database_is_populated(&user, &password, database)? {
        return Ok(());
    }

    let schema_path = ictx.build.git_path.join("exile.sql");
    let schema = fs::read_to_string(&schema_path).map_err(|e| {
        BuildError::Config(format!(
            "{e} — Could not read the Exile schema at {}",
            schema_path.display()
        ))
    })?;

    let schema = schema.replace(SCHEMA_DEFAULT_DATABASE, database);
    let local_schema = ictx
        .build
        .local_build_path
        .join(format!("exile-{database}.sql"));
    fs::write(&local_schema, &schema)?;

    let remote_schema = format!("/tmp/esm_schema_{database}.sql");
    copy_into_mysql(&local_schema, &remote_schema)?;
    run_mysql_script(&user, &password, None, &remote_schema)?;

    apply_esm_migrations(ictx, &user, &password, database)?;

    Ok(())
}

/// Apply ESM's additions to the Exile schema, in filename order.
///
/// These are plain `ALTER`/`CREATE` statements with no guard, which is safe because this only ever runs
/// against a database that was just created.
fn apply_esm_migrations(
    ictx: &InstanceContext,
    user: &str,
    password: &str,
    database: &str,
) -> BuildResult {
    let pattern = ictx
        .build
        .git_path
        .join("src")
        .join("@esm")
        .join("sql")
        .join("*.sql");

    let mut migrations: Vec<_> = glob::glob(&pattern.to_string_lossy())
        .map_err(|e| BuildError::General(e.to_string()))?
        .filter_map(|entry| entry.ok())
        .collect();
    migrations.sort();

    for migration in migrations {
        let name = migration
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .unwrap_or_default();

        let remote = format!("/tmp/esm_migration_{database}_{name}");
        copy_into_mysql(&migration, &remote)?;
        run_mysql_script(user, password, Some(database), &remote)?;
    }

    Ok(())
}

/// The database name `exile.sql` ships with, rewritten per server before the schema is loaded.
const SCHEMA_DEFAULT_DATABASE: &str = "exile_esm";

/// Whether the database already holds the Exile schema, checked via a table every install has.
fn database_is_populated(
    user: &str,
    password: &str,
    database: &str,
) -> Result<bool, BuildError> {
    let output = Command::new("docker")
        .args([
            "exec",
            "-e",
            &format!("MYSQL_PWD={password}"),
            MYSQL_CONTAINER,
            "mysql",
            &format!("-u{user}"),
            "--skip-column-names",
            "-e",
            &format!(
                "SELECT COUNT(*) FROM information_schema.tables \
                 WHERE table_schema = '{database}' AND table_name = 'account'"
            ),
        ])
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    Ok(String::from_utf8_lossy(&output.stdout).trim() == "1")
}

fn copy_into_mysql(local: &std::path::Path, remote: &str) -> BuildResult {
    let output = Command::new("docker")
        .args([
            "cp",
            &local.to_string_lossy(),
            &format!("{MYSQL_CONTAINER}:{remote}"),
        ])
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !output.status.success() {
        let msg = String::from_utf8_lossy(&output.stderr);
        return Err(BuildError::Docker(format!(
            "Failed to copy SQL into the MySQL container: {}",
            msg.trim()
        )));
    }

    Ok(())
}

/// Run a `.sql` file already inside the MySQL container. A `database` of `None` lets the script pick its own,
/// which is what the schema dump does.
fn run_mysql_script(
    user: &str,
    password: &str,
    database: Option<&str>,
    remote_path: &str,
) -> BuildResult {
    // The password goes through the environment rather than -p, so mysql's "insecure" warning stays out of
    // stderr and can't bury the actual error when a script fails.
    let mut args = vec![
        "exec".to_string(),
        "-e".to_string(),
        format!("MYSQL_PWD={password}"),
        MYSQL_CONTAINER.to_string(),
        "mysql".to_string(),
        format!("-u{user}"),
    ];

    if let Some(database) = database {
        args.push(database.to_string());
    }

    args.push("-e".to_string());
    args.push(format!("source {remote_path}"));

    let output = Command::new("docker")
        .args(&args)
        .output()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !output.status.success() {
        let err = String::from_utf8_lossy(&output.stderr);
        return Err(BuildError::Docker(format!(
            "MySQL script failed: {}",
            err.trim()
        )));
    }

    Ok(())
}

pub fn seed_database(ictx: &InstanceContext) -> BuildResult {
    let sql = generate_sql(ictx.config(), ictx.args().seed_xm8_notify);

    // One seed file per server, so concurrent runs can't overwrite each other's SQL mid-copy.
    let sql_path = ictx
        .build
        .local_build_path
        .join(format!("seed-{}.sql", ictx.instance.server_id));
    fs::write(&sql_path, &sql)?;

    // Credentials come from the shared mysql_uri; the database is this server's own, which is what confines
    // the wholesale DELETEs in the generated SQL to one server's data.
    let (user, password, _host_port) = parse_mysql_uri(&ictx.config().server.mysql_uri)?;
    let database = &ictx.instance.database;

    let remote_sql = format!("/tmp/esm_seed_{}.sql", ictx.instance.server_id);
    copy_into_mysql(&sql_path, &remote_sql)?;
    run_mysql_script(&user, &password, Some(database), &remote_sql)?;

    Ok(())
}

/// Split `mysql://user:password@host:port` into its parts.
///
/// A trailing `/database` is tolerated and ignored: which database to use is a per-server decision that lives
/// on the instance, not in the shared connection URI.
fn parse_mysql_uri(uri: &str) -> Result<(String, String, String), BuildError> {
    let without_scheme = uri
        .strip_prefix("mysql://")
        .ok_or_else(|| BuildError::Config(format!("Invalid mysql_uri: {uri}")))?;

    let (credentials, rest) = without_scheme.split_once('@').ok_or_else(|| {
        BuildError::Config(format!("Invalid mysql_uri (missing @): {uri}"))
    })?;

    let (user, password) = credentials.split_once(':').ok_or_else(|| {
        BuildError::Config(format!("Invalid mysql_uri (missing : in credentials): {uri}"))
    })?;

    let host_port = rest.split_once('/').map_or(rest, |(host, _)| host);

    Ok((
        user.to_string(),
        password.to_string(),
        host_port.to_string(),
    ))
}

// ─── SQL generation ──────────────────────────────────────────────────────────

fn generate_sql(config: &Config, xm8_notify: bool) -> String {
    let rng = &mut rand::rng();

    let mut steam_uids = generate_steam_uids(STEAM_UID_COUNT, rng);
    steam_uids.push(config.my_steam_uid.clone());

    let accounts = generate_accounts(&steam_uids, &config.my_steam_uid, rng);
    let players = generate_players(&accounts);
    let territories =
        generate_territories(&steam_uids, &config.my_steam_uid, xm8_notify);
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

fn generate_steam_uids(count: usize, rng: &mut impl Rng) -> Vec<String> {
    // Steam64 IDs are 17 digits and always start with the universe +
    // account-type prefix 7656119 for individual accounts. Mirrors the
    // service's Faker::Steam.uid so both seeders share the same shape.
    (0..count)
        .map(|_| {
            let suffix: String =
                (0..10).map(|_| rng.random_range(0..10).to_string()).collect();

            format!("7656119{suffix}")
        })
        .collect()
}

fn generate_accounts(
    steam_uids: &[String],
    my_steam_uid: &str,
    rng: &mut impl Rng,
) -> Vec<Account> {
    let online = choose_online(steam_uids, my_steam_uid, rng);

    steam_uids
        .iter()
        .enumerate()
        .map(|(index, uid)| {
            let (last_connect_at, last_disconnect_at) =
                connection_times(online.contains(&index), rng);

            // Exile keeps one row per account forever, so the first connection is the oldest thing on it. Anchoring
            // it to the last connection rather than to now keeps a two-year veteran from reading as brand new.
            let first_connect_at =
                last_connect_at - Duration::days(rng.random_range(1..730));

            Account {
                uid: uid.clone(),
                name: Name().fake::<String>().replace('\'', ""),
                score: (10_000..9_000_000).fake(),
                kills: (0..1000).fake(),
                deaths: (0..1000).fake(),
                locker: (10_000..9_000_000).fake(),
                total_connections: (0..50_000).fake(),
                first_connect_at: format_timestamp(first_connect_at),
                last_connect_at: format_timestamp(last_connect_at),
                last_disconnect_at: last_disconnect_at
                    .map(format_timestamp)
                    .unwrap_or_else(|| "NULL".into()),
            }
        })
        .collect()
}

// The indexes of the accounts left connected. My own account is always one of them, so the dashboards I'm testing
// against have a live player in them without having to reseed until the dice cooperate.
fn choose_online(
    steam_uids: &[String],
    my_steam_uid: &str,
    rng: &mut impl Rng,
) -> HashSet<usize> {
    let mut candidates: Vec<usize> = steam_uids
        .iter()
        .enumerate()
        .filter(|(_, uid)| uid.as_str() != my_steam_uid)
        .map(|(index, _)| index)
        .collect();

    candidates.shuffle(rng);

    let count = rng.random_range(MIN_ONLINE..=MAX_ONLINE);
    let mut online: HashSet<usize> =
        candidates.into_iter().take(count - 1).collect();

    if let Some(index) = steam_uids.iter().position(|uid| uid == my_steam_uid) {
        online.insert(index);
    }

    online
}

// A connect/disconnect pair. Exile reads an account as online when it has no disconnect on record or its last
// connect is the more recent of the two, so the pair is what decides the flag rather than a column of its own.
fn connection_times(
    online: bool,
    rng: &mut impl Rng,
) -> (DateTime<Local>, Option<DateTime<Local>>) {
    if online {
        let connected_at =
            Local::now() - Duration::minutes(rng.random_range(1..6 * 60));

        // Most players have played before; the rest are on their first session and have never disconnected, which
        // is the other way a row reads as online.
        let previous_session_ended = (rng.random_range(0..100) >= 20).then(|| {
            connected_at - Duration::minutes(rng.random_range(10..14 * MINUTES_PER_DAY))
        });

        return (connected_at, previous_session_ended);
    }

    let connected_at = random_last_connect(rng);
    let session = Duration::minutes(rng.random_range(5..5 * 60));

    // A session that would end in the future would read as still connected, so it gets clamped back to now.
    let disconnected_at = (connected_at + session).min(Local::now());

    (connected_at, Some(disconnected_at))
}

// Offline connect times are spread across the listing's look-back windows on purpose: each window needs enough rows
// to page through, and the oldest bucket proves the window filters rather than showing whatever exists.
fn random_last_connect(rng: &mut impl Rng) -> DateTime<Local> {
    let minutes_ago = match rng.random_range(0..100) {
        0..=24 => rng.random_range(30..MINUTES_PER_DAY),
        25..=59 => rng.random_range(MINUTES_PER_DAY..7 * MINUTES_PER_DAY),
        60..=84 => rng.random_range(7 * MINUTES_PER_DAY..30 * MINUTES_PER_DAY),
        _ => rng.random_range(30 * MINUTES_PER_DAY..180 * MINUTES_PER_DAY),
    };

    Local::now() - Duration::minutes(minutes_ago)
}

fn format_timestamp(at: DateTime<Local>) -> String {
    at.format("'%Y-%m-%d %H:%M:%S'").to_string()
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

fn generate_territories(
    steam_uids: &[String],
    my_steam_uid: &str,
    xm8_notify: bool,
) -> Vec<Territory> {
    let rng = &mut rand::rng();

    // Exile latches xm8_protectionmoney_notified per due cycle: a near/overdue
    // territory with notified = 0 fires a protection-money XM8 notification on
    // the next maintenance scan, then flips the flag. Seed the showcase as
    // already-notified so a routine dev start stays quiet - /me reads the due
    // dates, not this flag. --seed-xm8-notify arms them for one confirming round.
    let notified: u8 = if xm8_notify { 0 } else { 1 };

    // Deterministic showcase, all owned by me, so /me always shows the full
    // spread of payment/urgency states for UI testing. last_paid is a SQL
    // expression: with the default 7-day territory_lifetime, paying "N days ago"
    // leaves (7 - N) days until the next payment is due.
    //
    // (name, last_paid_at, flag_stolen)
    let showcase: Vec<(&str, &str, bool)> = vec![
        ("Paid Up Plains", "NOW()", false), // ~7 days out
        ("Four Day Fields", "DATE_SUB(NOW(), INTERVAL 3 DAY)", false), // 4 days left
        ("Two Day Township", "DATE_SUB(NOW(), INTERVAL 5 DAY)", false), // 2 days left
        (
            "Tomorrow Territory",
            "DATE_SUB(NOW(), INTERVAL 6 DAY)",
            false,
        ), // due tomorrow
        ("Due Today Domain", "DATE_SUB(NOW(), INTERVAL 7 DAY)", false), // due today
        ("Overdue Oasis", "DATE_SUB(NOW(), INTERVAL 9 DAY)", false), // 2 days overdue
        ("Stolen Sanctuary", "DATE_SUB(NOW(), INTERVAL 5 DAY)", true), // stolen + 2 days
    ];

    let mut territories: Vec<Territory> = Vec::new();
    let mut used_custom_ids: HashSet<String> = HashSet::new();

    for (name, last_paid, stolen) in showcase {
        let id = territories.len() + 1;
        territories.push(make_territory(
            id,
            my_steam_uid,
            steam_uids,
            rng,
            &mut used_custom_ids,
            name.to_string(),
            last_paid.to_string(),
            stolen,
            notified,
        ));
    }

    // One random territory per other player, so the world isn't only mine.
    // These are freshly paid (NOW()), so they never sit in the notify window
    // regardless of the flag - seed them already-notified unconditionally.
    for owner in steam_uids.iter().filter(|uid| uid.as_str() != my_steam_uid) {
        let id = territories.len() + 1;
        let name = CompanyName().fake::<String>().replace('\'', "");
        let stolen: bool = Boolean(50).fake();
        territories.push(make_territory(
            id,
            owner,
            steam_uids,
            rng,
            &mut used_custom_ids,
            name,
            "NOW()".to_string(),
            stolen,
            1,
        ));
    }

    territories
}

// esm_custom_id carries a UNIQUE index, and the fake username pool is small enough that a few hundred territories
// will draw the same name twice. A numeric suffix keeps the ids readable while guaranteeing the insert lands.
fn unique_custom_id(used: &mut HashSet<String>) -> String {
    if !Boolean(50).fake::<bool>() {
        return "NULL".into();
    }

    let base = Username().fake::<String>().replace('\'', "");
    let mut candidate = base.clone();
    let mut suffix = 2;

    while !used.insert(candidate.clone()) {
        candidate = format!("{base}{suffix}");
        suffix += 1;
    }

    format!("'{candidate}'")
}

fn make_territory(
    id: usize,
    owner: &str,
    steam_uids: &[String],
    rng: &mut impl rand::Rng,
    used_custom_ids: &mut HashSet<String>,
    name: String,
    last_paid_at: String,
    stolen: bool,
    notified: u8,
) -> Territory {
    let n = 5;

    let mut build_rights: Vec<String> = steam_uids.sample(rng, n).cloned().collect();
    build_rights.push(owner.to_string());
    build_rights.dedup();

    let mut moderators: Vec<String> = build_rights.sample(rng, n).cloned().collect();
    moderators.push(owner.to_string());
    moderators.dedup();

    Territory {
        id,
        esm_custom_id: unique_custom_id(used_custom_ids),
        owner_uid: owner.to_string(),
        name,
        position_x: (0.0..5000.0).fake(),
        position_y: (0.0..5000.0).fake(),
        position_z: (0.0..20.0).fake(),
        radius: (0.0..100.0).fake(),
        level: (1..7).fake(),
        flag_texture: FLAG_TEXTURES.choose(rng).unwrap().to_string(),
        flag_stolen: u8::from(stolen),
        flag_stolen_by_uid: if stolen {
            format!("'{}'", steam_uids.choose(rng).unwrap())
        } else {
            "NULL".into()
        },
        flag_stolen_at: if stolen { random_timestamp() } else { "NULL".into() },
        last_paid_at,
        xm8_protectionmoney_notified: notified,
        build_rights: format!("{build_rights:?}"),
        moderators: format!("{moderators:?}"),
    }
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
    first_connect_at: String, last_connect_at: String,
    last_disconnect_at: String,
}

impl Display for Account {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "('{uid}',{clan},'{name}',{score},{kills},{deaths},{locker},{first},{last_c},{last_d},'{total}')",
            uid = self.uid, clan = "NULL", name = self.name,
            score = self.score, kills = self.kills, deaths = self.deaths,
            locker = self.locker, first = self.first_connect_at,
            last_c = self.last_connect_at, last_d = self.last_disconnect_at,
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
    flag_stolen_by_uid: String, flag_stolen_at: String, last_paid_at: String,
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
            created = random_timestamp(), paid = self.last_paid_at,
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
