use super::*;

pub async fn check_if_territory_owner(
    context: &Database,
    connection: &mut Conn,
    territory_id: u64,
    steam_uid: &str,
) -> Result<bool, Error> {
    let owner_check: Option<String> = connection
        .exec_first(
            &context.statements.check_if_territory_owner,
            params! {
                "territory_id" => territory_id,
                "owner_uid" => steam_uid
            },
        )
        .await?;

    match owner_check {
        Some(is_owner) => Ok(is_owner == "true"),
        None => Ok(false),
    }
}
