use uuid::Uuid;

use super::*;

// Limit tampering
fn query() -> &'static str {
    r#"
    INSERT INTO
        xm8_notification (uuid, recipient_uid, territory_id, type, content)
    VALUES
        (:uuid, :uid, :territory_id, :type, :content);
    "#
}

pub async fn add_xm8_notifications(
    context: &Database,
    connection: &mut Conn,
    notification_type: String,
    recipient_uids: String,
    mut content: HashMap<String, String>,
) -> Result<(), Error> {
    let territory_id = &content.remove("territory_id");

    // If the XM8 notification comes with a territory ID, we need to encode it
    if let Some(id) = territory_id {
        let encoded_id = context.encode_territory_id(&id);

        content.insert("territory_id".into(), encoded_id);
    }

    let recipient_uids: Vec<String> = match serde_json::from_str(&recipient_uids) {
        Ok(u) => u,
        Err(e) => return Err(e.to_string().into()),
    };

    let content = serde_json::to_string(&content).map_err(|e| e.to_string())?;

    // Execute the query
    let result = connection
        .exec_batch(
            query(),
            recipient_uids.iter().map(|uid| {
                params! {
                    "uuid" => Uuid::new_v4().to_string(),
                    "uid" => &uid,
                    "territory_id" => territory_id,
                    "type" => &notification_type,
                    "content" => &content,
                }
            }),
        )
        .await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => Err(e.to_string().into()),
    }
}
