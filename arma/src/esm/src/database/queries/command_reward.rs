use super::*;

pub async fn command_reward_territories(
    _context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> DatabaseResult {
    let player_uid = match arguments.get("uid") {
        Some(uid) => uid,
        None => {
            error!("[command_reward_territories] ❌ Missing key `uid` in provided query arguments");
            return Err("error".into());
        }
    };

    #[derive(Debug, Serialize)]
    struct TerritoryResult {
        pub id: i32,
        pub custom_id: Option<String>,
        pub name: String,
        pub level: i32,
        pub vehicle_count: i32,
    }

    let result = connection
        .exec_map(
            r#"
SELECT
t.id,
esm_custom_id,
name,
level,
(SELECT COUNT(*) FROM vehicle WHERE territory_id = t.id) as vehicle_count
FROM
territory t
WHERE
deleted_at IS NULL
AND
(owner_uid = :uid
    OR build_rights LIKE :uid_wildcard
    OR moderators LIKE :uid_wildcard)
        "#,
            params! { "uid" => player_uid, "uid_wildcard" => format!("%{}%", player_uid) },
            |(id, custom_id, name, level, vehicle_count)| TerritoryResult {
                id,
                custom_id,
                name,
                level,
                vehicle_count,
            },
        )
        .await;

    match result {
        Ok(territories) => {
            let results: Vec<String> = territories
                .into_iter()
                .map(|t| serde_json::to_string(&t).unwrap())
                .collect();

            Ok(results)
        }
        Err(e) => {
            error!("[command_reward_territories] ❌ Query failed - {}", e);
            Err("error".into())
        }
    }
}
