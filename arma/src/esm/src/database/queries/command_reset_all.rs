use super::*;

pub async fn command_reset_all(
    context: &Database,
    connection: &mut Conn,
    _arguments: &HashMap<String, String>,
) -> QueryResult {
    let result = connection.query_drop(&context.sql.command_reset_all).await;

    match result {
        Ok(_) => Ok(vec![]),
        Err(e) => Err(QueryError::System(format!("Query failed - {}", e))),
    }
}
