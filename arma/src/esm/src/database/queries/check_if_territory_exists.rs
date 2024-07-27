use super::*;

pub async fn check_if_territory_exists(
    context: &Database,
    connection: &mut Conn,
    database_id: u64,
) -> Result<bool, Error> {
    let existence_check: Option<String> = connection
        .exec_first(
            &context.statements.check_if_territory_exists,
            params! {
                "territory_id" => database_id
            },
        )
        .await?;

    match existence_check {
        Some(exists) => Ok(exists == "true"),
        None => Ok(false),
    }
}
