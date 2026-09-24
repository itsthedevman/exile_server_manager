use super::*;

pub async fn update_xm8_attempt_counter(
    context: &Database,
    connection: &mut Conn,
    uuids: Vec<&String>,
) -> Result<(), Error> {
    let query = replace_list(&context.sql.update_xm8_attempt_counter, ":uuids", uuids.len());

    connection
        .exec_drop(&query, uuids)
        .await
        .map_err(|e| e.to_string().into())
}
