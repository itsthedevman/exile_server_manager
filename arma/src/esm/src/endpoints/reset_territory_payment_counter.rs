use parser::Parser;

use super::*;

pub fn reset_territory_payment_counter(database_ids: String) -> Result<(), String> {
    let timer = std::time::Instant::now();
    trace!(
        "[reset_territory_payment_counter] database_ids: {}",
        database_ids
    );

    // Convert the database Ids from "['1','2']" to [1,2]
    let database_ids: Vec<u64> =
        match Parser::from_arma::<Vec<String>>(&database_ids) {
            Ok(ids) => ids.iter().filter_map(|i| i.parse::<u64>().ok()).collect(),
            Err(e) => return Err(e),
        };

    if database_ids.is_empty() {
        return Err("No valid database IDs provided".into());
    }

    TOKIO_RUNTIME.block_on(async {
        for database_id in database_ids {
            DATABASE
                .set_territory_payment_counter(database_id, 0)
                .await
                .ok();
        }
    });

    debug!(
        "[reset_territory_payment_counter] ⏲ Took {:.2?}",
        timer.elapsed()
    );

    Ok(())
}
