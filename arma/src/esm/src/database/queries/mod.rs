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
import_and_export!(command_restore);
import_and_export!(command_reward);
import_and_export!(command_set_id);
import_and_export!(decode_territory_id);
import_and_export!(get_xm8_notifications);
import_and_export!(player_territories);
import_and_export!(set_territory_payment_counter);
import_and_export!(update_xm8_attempt_counter);
import_and_export!(update_xm8_notification_state);

// Generates a Queries struct containing these attributes and the contents of their
// corresponding SQL file. These files MUST exist in @esm/sql/queries or there will be errors
load_sql! {
    account_name_lookup,
    check_if_territory_exists,
    check_if_territory_owner,
    decode_territory_id,
    set_territory_payment_counter,

    // Command queries
    command_all_territories,
    command_me,
    command_restore_construction,
    command_restore_container,
    command_restore_territory,
    command_set_id,
    player_territories // Used by multiple commands
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

/*
{
    "territory_info",
    @"SELECT
        t.id as id,
        owner_uid,
        (SELECT name FROM account WHERE uid = owner_uid) as owner_name,
        name as territory_name,
        radius,
        level,
        flag_texture,
        flag_stolen,
        CONVERT_TZ(`last_paid_at`, @@session.time_zone, '+00:00') AS `last_paid_at`,
        build_rights,
        moderators,
        (SELECT COUNT(*) FROM construction WHERE territory_id = t.id) as object_count,
        esm_custom_id
    FROM
        territory t
    WHERE
        t.id = @tid"
},
{
    "list_territories_all",
    "SELECT t.id, owner_uid, a.name as owner_name, t.name, esm_custom_id FROM territory t INNER JOIN account a ON a.uid = owner_uid ORDER BY t.name ASC"
},
{
    "get_name",
    "SELECT name FROM account WHERE uid = @uid"
},
{
    "player_info_account_only",
    @"SELECT
        a.locker,
        a.score,
        a.name,
        a.kills,
        a.deaths,
        (
            SELECT CONCAT("[", GROUP_CONCAT(JSON_OBJECT("id", id, "name", name) SEPARATOR ", "), "]")
            FROM territory
            WHERE deleted_at IS NULL AND (owner_uid = @uid OR build_rights LIKE CONCAT('%', @uid, '%') OR moderators LIKE CONCAT('%', @uid, '%'))
        ) as territories
    FROM account a
    WHERE
        a.uid = @uid"
},
{
    "leaderboard",
    "SELECT name FROM account ORDER BY kills DESC LIMIT 10"
},
{
    "leaderboard_deaths",
    "SELECT name FROM account ORDER BY deaths DESC LIMIT 10"
},
{
    "leaderboard_score",
    "SELECT name FROM account ORDER BY score DESC LIMIT 10"
},
{
    "restore",
    @"UPDATE territory SET deleted_at = NULL, xm8_protectionmoney_notified = 0, last_paid_at = NOW() WHERE id = @tid;
    UPDATE construction SET deleted_at = NULL WHERE id = @tid;
    UPDATE container SET deleted_at = NULL WHERE id = @tid;"
},
{
    "reset_player",
    "DELETE FROM player WHERE account_uid = @uid"
},
{
    "reset_all",
    "DELETE FROM player WHERE damage = 1"
},
{
    "get_territory_id_from_hash",
    "SELECT id FROM territory WHERE esm_custom_id = @tid"
},
{
    "set_custom_territory_id",
    "UPDATE territory SET esm_custom_id = @tid WHERE id = @id AND owner_uid = @uid"
},
{
    "get_hash_from_id",
    "SELECT esm_custom_id FROM territory WHERE id = @id"
},
{
    "get_payment_count",
    "SELECT esm_payment_counter FROM territory WHERE id = @id"
},
{
    "increment_payment_counter",
    "UPDATE territory SET esm_payment_counter = esm_payment_counter + 1 WHERE id = @id"
},
{
    "reset_payment_counter",
    "UPDATE territory SET esm_payment_counter = 0 WHERE (owner_uid = @uid OR build_rights LIKE CONCAT('%', @uid, '%') OR moderators LIKE CONCAT('%', @uid, '%'))"
}
 */
