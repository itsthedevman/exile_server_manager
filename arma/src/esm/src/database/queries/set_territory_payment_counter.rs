use super::*;

pub async fn set_territory_payment_counter(
    context: &Database,
    connection: &mut Conn,
    database_id: usize,
    counter_value: usize,
) -> Result<(), Error> {
    let result = connection
        .exec_drop(
            &context.sql.set_territory_payment_counter,
            params! {
                "counter_value" => counter_value,
                "territory_id" => database_id
            },
        )
        .await;

    match result {
        Ok(_) => Ok(()),
        Err(e) => Err(e.to_string().into()),
    }
}
