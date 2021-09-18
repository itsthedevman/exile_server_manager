use chrono::NaiveDateTime;

#[derive(Debug, PartialEq, Eq)]
pub struct Account {
    uid: String,
    clan_id: Option<u32>,
    name: String,
    score: i32,
    kills: u32,
    deaths: u32,
    locker: i32,
    first_connect_at: NaiveDateTime,
    last_connect_at: NaiveDateTime,
    last_disconnect_at: Option<NaiveDateTime>,
    total_connections: u32,
}


#[derive(Debug)]
pub struct Territory {
    pub id: u32,
    pub esm_custom_id: Option<String>,
    pub owner_uid: String,
    pub name: String,
    pub radius: f64,
    pub level: i32,
    pub flag_texture: String,
    pub flag_stolen: bool,
    pub flag_stolen_by_uid: Option<String>,
    pub flag_stolen_at: Option<NaiveDateTime>,
    pub created_at: NaiveDateTime,
    pub last_paid_at: Option<NaiveDateTime>,
    pub xm8_protectionmoney_notified: bool,
    pub build_rights: String,
    pub moderators: String,
    pub esm_payment_counter: u32,
    pub deleted_at: Option<NaiveDateTime>,
}
