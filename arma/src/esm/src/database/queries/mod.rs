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
import_and_export!(command_player_info);
import_and_export!(command_player_territories);
import_and_export!(command_players_list);
import_and_export!(command_reset_all);
import_and_export!(command_reset_player);
import_and_export!(command_restore);
import_and_export!(command_reward);
import_and_export!(command_set_id);
import_and_export!(command_territory_info);
import_and_export!(decode_territory_id);
import_and_export!(get_xm8_notifications);
import_and_export!(get_territory_payment_counter);
import_and_export!(increment_territory_payment_counter);
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
    command_player_info,
    command_player_territories, // Used by multiple commands
    command_players_list,
    command_reset_all,
    command_reset_player,
    command_restore_construction,
    command_restore_container,
    command_restore_territory,
    command_set_id,
    command_territory_info,
    decode_territory_id,
    get_territory_payment_counter,
    increment_territory_payment_counter,
    set_territory_payment_counter
}

/// Read one column off a row, converted to `T`.
///
/// Ask for a fixed width. Every integer column here holds a domain value rather than a length, and `isize`/`usize`
/// follow the pointer width: 64 bits on the x64 build and 32 on the i686 one, so `money`, `kills`, `deaths` and
/// `total_connections` (all `int unsigned`, up to 4,294,967,295) stop converting past 2,147,483,647 on 32-bit
/// alone. `FromValue` reports that as an error, which takes the whole query down rather than the one field, and
/// the server it happens on is the only one that sees it.
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
