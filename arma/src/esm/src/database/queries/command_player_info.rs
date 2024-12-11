use super::*;

#[derive(Debug, Deserialize, Serialize)]
struct Territory {
    id: String,
    name: String,
}

#[derive(Debug, Deserialize, Serialize, Default)]
struct Account {
    uid: String,
    name: String,
    locker: isize,
    score: isize,
    kills: isize,
    deaths: isize,
    money: Option<isize>,
    damage: Option<f64>,
    hunger: Option<f64>,
    thirst: Option<f64>,
    territories: Vec<Territory>,
}

pub async fn command_player_info(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let player_uid = arguments.get("uid").ok_or(QueryError::User(
        "Missing key `uid` in provided query arguments".into(),
    ))?;

    let result: Option<Row> = connection
        .exec_first(&context.sql.command_player_info, params! { player_uid })
        .await
        .map_err(|e| QueryError::System(format!("Query failed - {}", e)))?;

    match result {
        Some(row) => {
            let result =
                convert_result(row, context).map_err(|e| QueryError::System(e))?;

            Ok(vec![result])
        }
        None => Ok(vec![]),
    }
}

fn convert_result(mut row: Row, context: &Database) -> Result<String, String> {
    let territories: String = select_column(&mut row, "territories")?;

    let territories = serde_json::from_str::<Vec<Territory>>(&territories)
        .map_err(|err| err.to_string())?
        .into_iter()
        .map(|mut territory| {
            territory.id = context.encode_territory_id(&territory.id);
            territory
        })
        .collect();

    let account = Account {
        uid: select_column(&mut row, "uid")?,
        name: select_column(&mut row, "name")?,
        locker: select_column(&mut row, "locker")?,
        score: select_column(&mut row, "score")?,
        kills: select_column(&mut row, "kills")?,
        deaths: select_column(&mut row, "deaths")?,
        money: select_column(&mut row, "money")?,
        damage: select_column(&mut row, "damage")?,
        hunger: select_column(&mut row, "hunger")?,
        thirst: select_column(&mut row, "thirst")?,
        territories,
    };

    Ok(serde_json::to_string(&account).map_err(|e| e.to_string())?)
}
