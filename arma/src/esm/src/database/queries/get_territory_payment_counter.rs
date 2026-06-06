use super::*;

pub async fn get_territory_payment_counter(
    context: &Database,
    connection: &mut Conn,
    database_id: usize,
) -> Result<usize, Error> {
    let result: Option<usize> = connection
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
