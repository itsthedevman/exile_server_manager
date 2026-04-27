use mysql_async::prelude::FromValue;
use mysql_async::FromValueError;
pub use mysql_async::Row;

pub use crate::database::*;
pub use crate::*;

// I have this separated so Rust compiler errors will be localized to a line vs the entire macro
import_and_export!(add_xm8_notifications);
import_and_export!(check_if_territory_exists);
import_and_export!(check_if_territory_owner);
import_and_export!(command_all_territories);
import_and_export!(command_me);
import_and_export!(command_player_info);
import_and_export!(command_player_territories);
import_and_export!(command_reset_all);
import_and_export!(command_reset_player);
import_and_export!(command_restore);
import_and_export!(command_reward);
import_and_export!(command_set_id);
import_and_export!(command_territory_info);
import_and_export!(decode_territory_id);
import_and_export!(get_xm8_notifications);
import_and_export!(set_territory_payment_counter);
import_and_export!(update_xm8_attempt_counter);
import_and_export!(update_xm8_notification_state);

// Generates a Queries struct containing these attributes and the contents of their
// corresponding SQL file. These files MUST exist in @esm/sql/queries or there will be errors
load_sql! {
    account_name_lookup,
    check_if_territory_exists,
    check_if_territory_owner,
    command_all_territories,
    command_me,
    command_player_info,
    command_player_territories, // Used by multiple commands
    command_reset_all,
    command_reset_player,
    command_restore_construction,
    command_restore_container,
    command_restore_territory,
    command_set_id,
    command_territory_info,
    decode_territory_id,
    set_territory_payment_counter
}

pub fn select_column<T>(row: &Row, index: &str) -> Result<T, String>
where
    T: FromValue,
{
    row.get_opt(index)
        .ok_or_else(|| format!("{index} does not exist on row: {row:?}"))
        .and_then(|v| v.map_err(|e: FromValueError| e.to_string()))
}

pub fn replace_list(query: &str, placeholder: &str, quantity: usize) -> String {
    // Annoying workaround for `IN` query, or insert multiple
    let placeholders = vec!["?"; quantity].join(",");
    query.replace(placeholder, &placeholders)
}
