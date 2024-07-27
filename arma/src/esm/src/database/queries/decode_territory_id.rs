use super::*;

pub async fn decode_territory_id(
    context: &Database,
    connection: &mut Conn,
    territory_id: &str,
) -> Result<u64, Error> {
    // Attempt to decode the ID since this is all done in Rust
    if let Some(database_id) = context.hasher.decode(&territory_id) {
        // Just because the hasher is able to decode it doesn't mean it is a valid database ID
        if queries::check_if_territory_exists(context, connection, database_id).await? {
            return Ok(database_id);
        }
    }

    // The ID was not hashed, check to see if it is a custom ID
    let result: SQLResult<Option<u64>> = connection
        .exec_first(
            &context.statements.decode_territory_id,
            params! { "custom_id" => territory_id },
        )
        .await;

    match result {
        Ok(r) => match r {
            Some(v) => Ok(v),
            None => Err("territory_id_does_not_exist".into()),
        },
        Err(e) => Err(e.to_string().into()),
    }
}
