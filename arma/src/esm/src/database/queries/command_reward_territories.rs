use super::*;

#[derive(Debug, Serialize)]
struct Territory {
    id: String,
    esm_custom_id: Option<String>,
    territory_name: String,
    level: i64,
    vehicle_count: i64,
}

pub async fn command_reward_territories(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let player_uid = arguments
        .get("uid")
        .ok_or_else(|| QueryError::User("Missing key `uid` in provided query arguments".into()))?;

    let rows: Vec<Row> = connection
        .exec(
            &context.sql.command_reward_territories,
            params! { "player_uid" => player_uid, "wildcard_uid" => format!("%{player_uid}%") },
        )
        .await
        .map_err(|e| QueryError::System(format!("Query failed - {e}")))?;

    rows.into_iter()
        .map(|row| convert_result(context, row).map_err(QueryError::System))
        .collect()
}

fn convert_result(context: &Database, row: Row) -> Result<String, String> {
    let id: i64 = select_column(&row, "id")?;

    let territory = Territory {
        id: context.encode_territory_id(&id.to_string()),
        esm_custom_id: select_column(&row, "esm_custom_id")?,
        territory_name: select_column(&row, "territory_name")?,
        level: select_column(&row, "level")?,
        vehicle_count: select_column(&row, "vehicle_count")?,
    };

    serde_json::to_string(&territory).map_err(|e| e.to_string())
}
