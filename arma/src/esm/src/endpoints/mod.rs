use crate::*;

import!(log_level);
import!(log_output);
import!(log);
import!(number_to_string);
import!(pre_init);
import!(send_message);
import!(send_to_channel);
import!(set_territory_payment_counter);
import!(utc_timestamp);

pub fn register() -> Extension {
    Extension::build()
        .command("log_level", log_level)
        .command("log_output", log_output)
        .command("log", log)
        .command("number_to_string", number_to_string)
        .command("pre_init", pre_init)
        .command("send_message", send_message)
        .command("send_to_channel", send_to_channel)
        .command("utc_timestamp", utc_timestamp)
        .command(
            "set_territory_payment_counter",
            set_territory_payment_counter,
        )
        .finish()
}
