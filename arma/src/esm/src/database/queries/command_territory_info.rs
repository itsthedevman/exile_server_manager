use super::*;

pub async fn command_territory_info(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let territory_id =
        arguments.get("territory_id").ok_or(QueryError::User(
            "Missing key `territory_id` in provided query arguments".into(),
        ))?;

    let territory_id =
        queries::decode_territory_id(context, connection, territory_id).await?;

    // Optional: when present the SQL scopes the lookup to a territory this uid has
    // rights to; when absent (the admin `info` command) both bind to NULL and the
    // query returns the territory unconditionally. See command_territory_info.sql.
    let requesting_uid = arguments.get("requesting_uid");
    let wildcard_uid = requesting_uid.map(|uid| format!("%{}%", uid));

    let result = connection
        .exec_map(
            &context.sql.command_territory_info,
            params! {
                "territory_id" => territory_id,
                "requesting_uid" => requesting_uid,
                "wildcard_uid" => wildcard_uid,
            },
            map_results,
        )
        .await;

    match result {
        Ok(territories) => {
            if territories.is_empty() {
                return Ok(vec![]);
            }

            let errors = territories
                .iter()
                .filter_map(|result| result.as_ref().err())
                .map(|err| err.to_string())
                .collect::<Vec<String>>()
                .join(", ");

            if !errors.is_empty() {
                return Err(QueryError::System(format!(
                    "Query failed - {}",
                    errors
                )));
            }

            let territories: Vec<Territory> =
                territories.into_iter().filter_map(Result::ok).collect();

            let territories: Vec<String> =
                update_id_and_names(context, connection, territories)
                    .await?
                    .into_iter()
                    .filter_map(|t| serde_json::to_string(&t).ok())
                    .collect();

            Ok(territories)
        }
        Err(e) => Err(QueryError::System(format!("Query failed - {}", e))),
    }
}
