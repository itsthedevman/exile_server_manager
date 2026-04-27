use super::*;

// Limit tampering
fn query() -> &'static str {
    r#"
    UPDATE
        xm8_notification
    SET
        state = "pending",
        state_details = "attempting delivery",
        attempt_count = attempt_count + 1,
        last_attempt_at = CURRENT_TIME()
    WHERE
        uuid IN (:uuids);
    "#
}

pub async fn update_xm8_attempt_counter(
    _context: &Database,
    connection: &mut Conn,
    uuids: Vec<&String>,
) -> Result<(), Error> {
    let query = replace_list(query(), ":uuids", uuids.len());

    connection
        .exec_drop(&query, uuids)
        .await
        .map_err(|e| e.to_string().into())
}
