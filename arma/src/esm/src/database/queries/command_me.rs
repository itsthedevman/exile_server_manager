use super::*;

#[derive(Debug, Deserialize, Serialize)]
struct TerritoryResult {
    id: String,
    name: String,
}

#[derive(Debug, Serialize)]
struct PlayerResult {
    locker: i32,
    score: i32,
    name: String,
    money: Option<i32>,
    damage: Option<f64>,
    hunger: Option<f64>,
    thirst: Option<f64>,
    kills: i32,
    deaths: i32,
    territories: Vec<TerritoryResult>,
}

pub async fn command_me(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> DatabaseResult {
    let player_uid = match arguments.get("uid") {
        Some(uid) => uid,
        None => {
            error!("[query_me] ❌ Missing key `uid` in provided query arguments");
            return Err("error".into());
        }
    };

    let result = connection
        .exec_map(
            &context.statements.command_me,
            params! { "player_uid" => player_uid, "wildcard_uid" => format!("%{}%", player_uid) },
            |(locker, score, name, money, damage, hunger, thirst, kills, deaths, territories)| {
                let territories_json: Option<String> = territories;
                let mut territories = vec![];

                if let Some(territories_json) = territories_json {
                    if let Ok(territories_parsed) =
                        serde_json::from_str::<Vec<TerritoryResult>>(&territories_json)
                    {
                        territories_parsed.into_iter().for_each(|mut territory| {
                            territory.id = context.hasher.encode(territory.id);
                            territories.push(territory);
                        });
                    }
                }

                PlayerResult {
                    locker,
                    score,
                    name,
                    money,
                    damage,
                    hunger,
                    thirst,
                    kills,
                    deaths,
                    territories,
                }
            },
        )
        .await;

    match result {
        Ok(players) => {
            let results: Vec<String> = players
                .into_iter()
                .map(|player| serde_json::to_string(&player).unwrap())
                .collect();

            Ok(results)
        }
        Err(e) => {
            error!("[query_me] ❌ Query failed - {}", e);
            Err("error".into())
        }
    }
}
