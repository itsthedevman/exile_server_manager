use chrono::NaiveDateTime;

#[derive(Queryable, Debug)]
pub struct Territory {
    pub id: u32,
    pub esm_custom_id: Option<String>,
    pub owner_uid: String,
    pub name: String,
    pub position_x: f64,
    pub position_y: f64,
    pub position_z: f64,
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
