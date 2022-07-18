use chrono::prelude::*;
use fake::{
    faker::{boolean::en::Boolean, chrono::en::DateTimeBetween, company::en::CompanyName},
    faker::{internet::en::Username, name::en::Name},
    Fake,
};
use lazy_static::lazy_static;
use rand::seq::SliceRandom;
use std::fmt::Display;

use crate::data::Data;

lazy_static! {
    pub static ref FLAG_TEXTURES: &'static [&'static str] = &[
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_bis_co.paa",
        "exile_assets\\\\texture\\\\flag&\\\\flag_mate_vish_co.paa",
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
        "exile_assets\\\\texture\\\\flag\\\\flag_country_de_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_at_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_sct_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_ee_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_cz_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_nl_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_hr_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_cn_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_ru_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_ir_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_by_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_fi_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_fr_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_au_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_be_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_se_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_pl_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_pl2_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_pt_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_mate_zanders_streched_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_brunswik_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_dorset_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_svarog_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_exile_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_utcity_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_dickbutt_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_rainbow_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_battleye_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_bss_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_skippy_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_kiwifern_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_trololol_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_dream_cat_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_pirate_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_pedobear_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_petoria_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_smashing_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_lemonparty_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_rma_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_cp_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_trouble2_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_exile_city_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_eraser1_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_willbeeaten_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_privateproperty_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_nuclear_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_lazerkiwi_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_beardageddon_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_dk_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_country_it_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_alkohol_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_kickass_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_knuckles_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_snake_co.paa",
        "exile_assets\\\\texture\\\\flag\\\\flag_misc_weeb_co.paa"
    ];
}

pub struct Database {}

impl Database {
    pub fn generate_sql(data: Data) -> String {
        let mut steam_uids = data.steam_uids.to_owned();
        steam_uids.push(data.dev.steam_uid);

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

                INSERT INTO account VALUES
                {accounts};

                INSERT INTO player VALUES
                {players};

                INSERT INTO territory VALUES
                {territories};

                INSERT INTO construction VALUES
                {constructions};
            "#,
            accounts = map_to_string(accounts),
            players = map_to_string(players),
            territories = map_to_string(territories),
            constructions = map_to_string(constructions)
        )
    }
}

fn map_to_string<T: ToString>(vec: Vec<T>) -> String {
    vec.iter()
        .map(|x| x.to_string())
        .collect::<Vec<String>>()
        .join(",\n")
}

fn random_timestamp() -> String {
    let current_time = Local::now();

    let start_time = current_time.with_month(1).unwrap().with_day(1).unwrap();
    let end_time = current_time.with_month(12).unwrap().with_day(31).unwrap();

    let random_time: DateTime<Utc> =
        DateTimeBetween(start_time.with_timezone(&Utc), end_time.with_timezone(&Utc)).fake();

    random_time
        .with_timezone(&Local)
        .format("'%Y-%m-%d %H:%M:%S'")
        .to_string()
}

fn generate_accounts(steam_uids: &[String]) -> Vec<Account> {
    steam_uids
        .iter()
        .map(|steam_uid| Account {
            uid: steam_uid.to_owned(),
            name: Name().fake::<String>().replace('\'', ""),
            score: (10000..9000000).fake(),
            kills: (0..1000).fake(),
            deaths: (0..1000).fake(),
            locker: (10000..9000000).fake(),
            total_connections: (0..50000).fake(),
        })
        .collect()
}

fn generate_players(accounts: &[Account]) -> Vec<Player> {
    accounts
        .iter()
        .enumerate()
        .map(|(i, account)| Player {
            id: i + 1,
            name: account.name.to_owned(),
            account_uid: account.uid.to_owned(),
            money: (10000..9000000).fake(),
            damage: (0.0..0.9).fake(),
            hunger: (0..100).fake(),
            thirst: (0..100).fake(),
            alcohol: (0..=5).fake(), // 5 is drunk
            temperature: (34..=37).fake(),
            wetness: (0.0..=1.0).fake(),
            oxygen_remaining: (0.4..1.0).fake(),
            bleeding_remaining: (0.0..1.0).fake(),
        })
        .collect()
}

fn generate_territories(steam_uids: &[String]) -> Vec<Territory> {
    let rng = &mut rand::thread_rng();
    let number_of_uids = steam_uids.len();

    steam_uids
        .iter()
        .enumerate()
        .map(|(i, owner_uid)| {
            let mut build_rights: Vec<String> = steam_uids
                .choose_multiple(rng, number_of_uids)
                .cloned()
                .collect();

            // Owner UID must be in both build_rights and moderators
            build_rights.push(owner_uid.to_owned());
            build_rights.dedup();

            let mut moderators: Vec<String> = build_rights
                .choose_multiple(rng, number_of_uids)
                .cloned()
                .collect();

            // Owner UID must be in both build_rights and moderators
            moderators.push(owner_uid.to_owned());
            moderators.dedup();

            let generate_custom_id: bool = Boolean(50).fake();
            let stolen: bool = Boolean(50).fake();
            Territory {
                id: i + 1,
                esm_custom_id: if generate_custom_id {
                    format!("'{}'", Username().fake::<String>().replace('\'', ""))
                } else {
                    "NULL".into()
                },
                owner_uid: owner_uid.to_owned(),
                name: CompanyName().fake::<String>().replace('\'', ""),
                position_x: (0.0..5000.0).fake(),
                position_y: (0.0..5000.0).fake(),
                position_z: (0.0..20.0).fake(),
                radius: (0.0..100.0).fake(),
                level: (0..7).fake(),
                flag_texture: FLAG_TEXTURES.choose(rng).unwrap().to_string(),
                flag_stolen: if stolen { 1 } else { 0 },
                flag_stolen_by_uid: if stolen {
                    format!("'{}'", steam_uids.choose(rng).unwrap())
                } else {
                    "NULL".into()
                },
                flag_stolen_at: if stolen {
                    random_timestamp()
                } else {
                    "NULL".into()
                },
                xm8_protectionmoney_notified: 0,
                build_rights: format!("{:?}", build_rights),
                moderators: format!("{:?}", moderators),
            }
        })
        .collect()
}

fn generate_constructions(territories: &[Territory]) -> Vec<Construction> {
    territories
        .iter()
        .enumerate()
        .map(|(i, territory)| Construction {
            id: i + 1,
            account_uid: territory.owner_uid.to_owned(),
            spawned_at: random_timestamp(),
            position_x: territory.position_x,
            position_y: territory.position_y,
            position_z: territory.position_z,
            is_locked: 0,
            territory_id: territory.id,
        })
        .collect()
}

struct Account {
    uid: String,
    name: String,
    score: isize,
    kills: usize,
    deaths: usize,
    locker: isize,
    total_connections: usize,
}

#[allow(clippy::write_literal)]
impl Display for Account {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "('{uid}',{clan_id},'{name}',{score},{kills},{deaths},{locker},{first_connect_at},{last_connect_at},{last_disconnect_at},'{total_connections}')",
            uid = self.uid,
            clan_id = "NULL",
            name = self.name,
            score = self.score,
            kills = self.kills,
            deaths = self.deaths,
            locker = self.locker,
            first_connect_at = random_timestamp(),
            last_connect_at = "NOW()",
            last_disconnect_at = random_timestamp(),
            total_connections = self.total_connections,
        )
    }
}

struct Player {
    id: usize,
    name: String,
    account_uid: String,
    money: usize,
    damage: f64,
    hunger: usize,
    thirst: usize,
    alcohol: usize,
    temperature: usize,
    wetness: f64,
    oxygen_remaining: f64,
    bleeding_remaining: f64,
}

#[allow(clippy::write_literal)]
impl Display for Player {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({id},'{name}','{account_uid}',{money},{damage},{hunger},{thirst},{alcohol},{temperature},{wetness},{oxygen_remaining},{bleeding_remaining},'{hitpoints}',{direction},{position_x},{position_y},{position_z},{spawned_at},'{assigned_items}','{backpack}','{backpack_items}','{backpack_magazines}','{backpack_weapons}','{current_weapon}','{goggles}','{handgun_items}','{handgun_weapon}','{headgear}','{binocular}','{loaded_magazines}','{primary_weapon}','{primary_weapon_items}','{secondary_weapon}','{secondary_weapon_items}','{uniform}','{uniform_items}','{uniform_magazines}','{uniform_weapons}','{vest}','{vest_items}','{vest_magazines}','{vest_weapons}',{last_updated_at})",
            id = self.id,
            name = self.name,
            account_uid = self.account_uid,
            money = self.money,
            damage = self.damage,
            hunger = self.hunger,
            thirst = self.thirst,
            alcohol = self.alcohol,
            temperature = self.temperature,
            wetness = self.wetness,
            oxygen_remaining = self.oxygen_remaining,
            bleeding_remaining = self.bleeding_remaining,
            hitpoints = "[[\"face_hub\",0],[\"neck\",0],[\"head\",0],[\"pelvis\",0],[\"spine1\",0],[\"spine2\",0],[\"spine3\",0],[\"body\",0],[\"arms\",0],[\"hands\",0],[\"legs\",0],[\"body\",0]]",
            direction = 0,
            position_x = 9157, // Tanoa
            position_y = 10005, // Tanoa
            position_z = 0, // Tanoa
            spawned_at = random_timestamp(),
            assigned_items = "[\"ItemMap\",\"ItemCompass\",\"Exile_Item_XM8\",\"ItemRadio\"]",
            backpack = "B_Carryall_oli",
            backpack_items = "[]",
            backpack_magazines = "[]",
            backpack_weapons = "[]",
            current_weapon = "",
            goggles = "",
            handgun_items = "[]",
            handgun_weapon = "",
            headgear = "",
            binocular = "",
            loaded_magazines = "[]",
            primary_weapon = "",
            primary_weapon_items = "[\"\",\"\",\"\",\"\"]",
            secondary_weapon = "",
            secondary_weapon_items = "[\"\",\"\",\"\",\"\"]",
            uniform = "",
            uniform_items = "[]",
            uniform_magazines = "[]",
            uniform_weapons = "[]",
            vest = "",
            vest_items = "[]",
            vest_magazines = "[]",
            vest_weapons = "[]",
            last_updated_at = random_timestamp(),
        )
    }
}

struct Territory {
    id: usize,
    esm_custom_id: String,
    owner_uid: String,
    name: String,
    position_x: f64,
    position_y: f64,
    position_z: f64,
    radius: f64,
    level: isize,
    flag_texture: String,
    flag_stolen: u8, // Bool
    flag_stolen_by_uid: String,
    flag_stolen_at: String,
    xm8_protectionmoney_notified: u8, // Bool
    build_rights: String,
    moderators: String,
}

#[allow(clippy::write_literal)]
impl Display for Territory {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({id},{esm_custom_id},'{owner_uid}','{name}',{position_x},{position_y},{position_z},{radius},{level},'{flag_texture}',{flag_stolen},{flag_stolen_by_uid},{flag_stolen_at},{created_at},{last_paid_at},{xm8_protectionmoney_notified},'{build_rights}','{moderators}',{esm_payment_counter},{deleted_at})",
            id = self.id,
            esm_custom_id = self.esm_custom_id,
            owner_uid = self.owner_uid,
            name = self.name,
            position_x = self.position_x,
            position_y = self.position_y,
            position_z = self.position_z,
            radius = self.radius,
            level = self.level,
            flag_texture = self.flag_texture,
            flag_stolen = self.flag_stolen,
            flag_stolen_by_uid = self.flag_stolen_by_uid,
            flag_stolen_at = self.flag_stolen_at,
            created_at = random_timestamp(),
            last_paid_at = "NOW()",
            xm8_protectionmoney_notified = self.xm8_protectionmoney_notified,
            build_rights = self.build_rights,
            moderators = self.moderators,
            esm_payment_counter = 0,
            deleted_at = "NULL"
        )
    }
}

struct Construction {
    id: usize,
    account_uid: String,
    spawned_at: String,
    position_x: f64,
    position_y: f64,
    position_z: f64,
    is_locked: u8, // Bool
    territory_id: usize,
}

#[allow(clippy::write_literal)]
impl Display for Construction {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(
            f,
            "({id},'{class}','{account_uid}',{spawned_at},{position_x},{position_y},{position_z},{direction_x},{direction_y},{direction_z},{up_x},{up_y},{up_z},{is_locked},'{pin_code}',{damage},{territory_id},{last_updated_at},{deleted_at})",
            id = self.id,
            class = "Exile_Construction_WoodWall_Static",
            account_uid = self.account_uid,
            spawned_at = self.spawned_at,
            position_x = self.position_x,
            position_y = self.position_y,
            position_z = self.position_z,
            direction_x = 0,
            direction_y =0,
            direction_z = 0,
            up_x = 0,
            up_y = 0,
            up_z = 0,
            is_locked = self.is_locked,
            pin_code = "000000",
            damage = 0,
            territory_id = self.territory_id,
            last_updated_at = "NOW()",
            deleted_at = "NULL",
        )
    }
}
