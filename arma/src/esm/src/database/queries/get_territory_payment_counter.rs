use super::*;

pub async fn get_territory_payment_counter(
    context: &Database,
    connection: &mut Conn,
    database_id: u64,
) -> Result<u64, Error> {
    let result: Option<u64> = connection
        .exec_first(
            &context.sql.get_territory_payment_counter,
            params! {
                "territory_id" => database_id
            },
        )
        .await?;

    match result {
        Some(i) => Ok(i),
        None => Ok(0),
    }
}
