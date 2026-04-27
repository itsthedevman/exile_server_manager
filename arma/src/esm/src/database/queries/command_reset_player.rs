use super::*;

pub async fn command_reset_player(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let target_uid = arguments.get("uid").ok_or(QueryError::User(
        "Missing key `uid` in provided query arguments".into(),
    ))?;

    let result = connection
        .exec_drop(
            &context.sql.command_reset_player,
            params! { "uid" => target_uid },
        )
        .await;

    match result {
        Ok(_) => Ok(vec![]),
        Err(e) => Err(QueryError::System(format!("Query failed - {}", e))),
    }
}
