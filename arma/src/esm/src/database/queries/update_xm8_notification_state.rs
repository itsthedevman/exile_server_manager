use super::*;

#[derive(Deserialize, Serialize)]
struct NotificationState {
    pub state: String,
    pub state_details: String,
}

// Limit tampering
fn query() -> &'static str {
    r#"
    UPDATE
        xm8_notification
    SET
        state = :state,
        state_details = :state_details,
        acknowledged_at = CURRENT_TIME()
    WHERE
        uuid = :uuid;
    "#
}

pub async fn update_xm8_notification_state(
    _context: &Database,
    connection: &mut Conn,
    state_by_uuid: HashMap<String, JSONValue>,
) -> Result<(), QueryError> {
    let state_by_uuid: HashMap<String, NotificationState> = state_by_uuid
        .into_iter()
        .filter_map(|(key, value)| {
            match serde_json::from_value::<NotificationState>(value.to_owned()) {
                Ok(state) => Some((key, state)),
                Err(_) => None,
            }
        })
        .collect();

    connection
        .exec_batch(
            query(),
            state_by_uuid.iter().map(|(uuid, state)| {
                params! {
                    "uuid" => uuid,
                    "state" => &state.state,
                    "state_details" => &state.state_details,
                }
            }),
        )
        .await
        .map_err(|e| QueryError::System(e.to_string()))
}
