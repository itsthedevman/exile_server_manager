use parser::Parser;

use super::*;

pub fn set_territory_payment_counter(
    database_ids: String,
    counter_value: String,
) -> Result<(), String> {
    let timer = std::time::Instant::now();
    trace!(
        "[set_territory_payment_counter] database_ids: {}, counter_value: {}",
        database_ids,
        counter_value
    );

    // Convert the database Ids from "['1','2']" to [1,2]
    let database_ids: Vec<usize> = match Parser::from_arma::<Vec<String>>(&database_ids) {
        Ok(ids) => ids.iter().filter_map(|i| i.parse::<usize>().ok()).collect(),
        Err(e) => return Err(e),
    };

    if database_ids.is_empty() {
        return Err("No valid database IDs provided".into());
    }

    let counter_value = match counter_value.parse::<usize>() {
        Ok(v) => v,
        Err(e) => {
            error!("[#set_territory_payment_counter] {e}");
            return Err("Invalid value provided as the counter".into());
        }
    };

    TOKIO_RUNTIME.block_on(async {
        for database_id in database_ids {
            DATABASE
                .set_territory_payment_counter(database_id, counter_value)
                .await
                .ok();
        }
    });

    debug!(
        "[set_territory_payment_counter] ⏲ Took {:.2?}",
        timer.elapsed()
    );

    Ok(())
}
