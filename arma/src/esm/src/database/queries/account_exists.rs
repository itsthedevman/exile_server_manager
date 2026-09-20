use super::*;

#[derive(Debug, Serialize)]
struct Account {
    uid: String,
}

pub async fn account_exists(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let uid = arguments
        .get("uid")
        .ok_or_else(|| QueryError::User("Missing key `uid` in provided query arguments".into()))?;

    let rows: Vec<Row> = connection
        .exec(&context.sql.account_exists, params! { uid })
        .await
        .map_err(|e| QueryError::System(format!("Query failed - {e}")))?;

    rows.into_iter()
        .map(|row| convert_result(row).map_err(QueryError::System))
        .collect()
}

fn convert_result(row: Row) -> Result<String, String> {
    let account = Account {
        uid: select_column(&row, "uid")?,
    };

    serde_json::to_string(&account).map_err(|e| e.to_string())
}
