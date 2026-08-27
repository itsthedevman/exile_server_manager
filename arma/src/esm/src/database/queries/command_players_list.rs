use super::*;

#[derive(Debug, Deserialize, Serialize)]
struct Account {
    uid: String,
    name: String,
    locker: i64,
    score: i64,
    kills: i64,
    deaths: i64,
    first_connect_at: NaiveDateTime,
    last_connect_at: NaiveDateTime,
    last_disconnect_at: Option<NaiveDateTime>,
    total_connections: i64,
    money: Option<i64>,
    damage: Option<f64>,
    online: bool,
}

// The listing answers "who is around", so it is capped rather than paged. An admin
// who already holds a uid opens that player directly and never needs the tail.
const DEFAULT_ROW_LIMIT: u32 = 250;

pub async fn command_players_list(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let row_limit = match arguments.get("limit") {
        Some(limit) => limit.parse::<u32>().map_err(|e| {
            QueryError::User(format!("Invalid `limit` in query arguments - {e}"))
        })?,
        None => DEFAULT_ROW_LIMIT,
    };

    // A blank name is treated as absent. Left as-is it becomes LIKE '%%', which quietly returns the
    // whole account table dressed up as a search result.
    let name = arguments.get("name").filter(|name| !name.trim().is_empty());

    let (statement, parameters) = match name {
        Some(name) => (
            &context.sql.command_players_matching_name,
            params! { name, row_limit },
        ),
        None => {
            let connected_since =
                arguments.get("connected_since").ok_or(QueryError::User(
                    "Missing key `connected_since` in provided query arguments".into(),
                ))?;

            (
                &context.sql.command_players_recently_connected,
                params! { connected_since, row_limit },
            )
        }
    };

    let rows: Vec<Row> = connection
        .exec(statement, parameters)
        .await
        .map_err(|e| QueryError::System(format!("Query failed - {}", e)))?;

    rows.into_iter()
        .map(|row| convert_result(row).map_err(QueryError::System))
        .collect()
}

fn convert_result(row: Row) -> Result<String, String> {
    let account = Account {
        uid: select_column(&row, "uid")?,
        name: select_column(&row, "name")?,
        locker: select_column(&row, "locker")?,
        score: select_column(&row, "score")?,
        kills: select_column(&row, "kills")?,
        deaths: select_column(&row, "deaths")?,
        first_connect_at: select_column(&row, "first_connect_at")?,
        last_connect_at: select_column(&row, "last_connect_at")?,
        last_disconnect_at: select_column(&row, "last_disconnect_at")?,
        total_connections: select_column(&row, "total_connections")?,
        money: select_column(&row, "money")?,
        damage: select_column(&row, "damage")?,
        online: select_column(&row, "online")?,
    };

    serde_json::to_string(&account).map_err(|e| e.to_string())
}
