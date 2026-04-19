//! The `check_update` arma-rs command.
//!
//! Called from SQF during `preInit` — before `exile_server_manager` makes
//! its first `callExtension "esm"` call — giving the updater a window to
//! swap in a new `esm.dll/.so` while the file is not yet loaded.

use std::time::{Duration, Instant};
use updater_lib::Updater;

/// Check for and apply an ESM extension update.
///
/// Computes a deadline from `config.updater_timeout_ms`, then delegates to
/// `updater_lib::Updater::run_boot_check`. Always returns a human-readable
/// string logged to the Arma RPT — never panics or blocks indefinitely.
///
/// Possible return values:
/// - `"No updates available."` — running version is current, or check failed
///   safely (fail-open).
/// - `"Auto-updater is disabled."` — updater disabled in `config.yml`.
/// - `"Successfully updated <component> to v<X.Y.Z>."` — swap succeeded.
/// - `"Update pending for <component>: <reason>."` — update deferred.
/// - `"Update failed: <reason>."` — error surfaced from `run_boot_check`.
pub fn check_update() -> String {
    let deadline =
        Instant::now() + Duration::from_millis(crate::CONFIG.updater_timeout_ms);

    match Updater::run_boot_check(deadline) {
        Ok(boot_result) => boot_result.to_status_string(),
        Err(error) => {
            log::error!("[check_update] update failed: {error}");
            format!("Update failed: {error}.")
        }
    }
}
