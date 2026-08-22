use super::*;

pub async fn increment_territory_payment_counter(
    context: &Database,
    connection: &mut Conn,
    database_id: u64,
) -> Result<(), Error> {
    let result = connection
        .exec_drop(
            &context.sql.increment_territory_payment_counter,
            params! {
                "territory_id" => database_id
            },
        )
        .await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => Err(e.to_string().into()),
    }
}
