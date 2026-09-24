use super::*;

#[derive(Serialize, Deserialize, Debug)]
pub struct Notification {
    pub uuids: Vec<String>,
    pub recipient_uids: Vec<String>,

    #[serde(rename = "type")]
    pub notification_type: String,

    pub content: String,
    pub created_at: NaiveDateTime,
}

impl Notification {
    fn from_tuple(
        tuple: (String, String, String, String, NaiveDateTime),
    ) -> Result<Self, String> {
        Ok(Self {
            uuids: serde_json::from_str(&tuple.0).map_err(|e| e.to_string())?,
            recipient_uids: serde_json::from_str(&tuple.1).map_err(|e| e.to_string())?,
            notification_type: tuple.2,
            content: tuple.3,
            created_at: tuple.4,
        })
    }
}

pub async fn get_xm8_notifications(
    context: &Database,
    connection: &mut Conn,
) -> Result<Vec<Notification>, Error> {
    let result = connection
        .query_map(&context.sql.get_xm8_notifications, |r| Notification::from_tuple(r))
        .await;

    let notifications = match result {
        Ok(notifications) => notifications,
        Err(e) => return Err(e.to_string().into()),
    };

    notifications
        .into_iter()
        .collect::<Result<Vec<Notification>, String>>()
        .map_err(|e| e.to_string().into())
}
