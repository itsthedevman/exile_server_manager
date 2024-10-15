use super::*;

pub async fn command_set_id(
    context: &Database,
    connection: &mut Conn,
    arguments: &HashMap<String, String>,
) -> QueryResult {
    let Some(steam_uid) = arguments.get("steam_uid") else {
        return Err(QueryError::User(
            "Missing key `steam_uid` in provided query arguments".into(),
        ));
    };

    let Some(territory_id) = arguments.get("territory_id") else {
        return Err(QueryError::User(
            "Missing key `territory_id` in provided query arguments".into(),
        ));
    };

    let Some(new_territory_id) = arguments.get("new_territory_id") else {
        return Err(QueryError::User(
            "Missing key `new_territory_id` in provided query arguments".into(),
        ));
    };

    // This handles both hashed IDs or custom
    let territory_id =
        queries::decode_territory_id(context, connection, territory_id).await?;

    // Territory admins can bypass this check.
    // Otherwise, check to see if the steam_uid is the owner's
    if !arma::is_territory_admin(&steam_uid) {
        let is_owner = queries::check_if_territory_owner(
            context,
            connection,
            territory_id,
            steam_uid,
        )
        .await?;

        if !is_owner {
            // This might seem odd but pretending the territory ID doesn't exist
            // means we're not accidentally exposing if an encoded/custom ID exists in the DB
            return Err(QueryError::Code("territory_id_does_not_exist".into()));
        }
    }

    let result = connection
        .exec_drop(
            &context.sql.command_set_id,
            params! {
                "territory_id" => territory_id,
                "custom_id" => new_territory_id
            },
        )
        .await;

    match result {
        Ok(_) => Ok(vec![]),
        Err(e) => Err(QueryError::System(format!("Query failed - {}", e))),
    }
}
