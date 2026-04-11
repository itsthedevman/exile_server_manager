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
/// `updater_lib::Updater::run_boot_check`. Always returns a short ASCII
/// string safe to log from SQF — never panics or blocks indefinitely.
///
/// Possible return values:
/// - `"ok"` — no update needed, or check failed safely (fail-open).
/// - `"disabled"` — updater is disabled in `config.yml`.
/// - `"updated:esm:X.Y.Z"` — extension was updated successfully.
/// - `"pending:<component>:<reason>"` — update available but deferred.
/// - `"error:internal"` — unexpected panic caught (should never happen).
pub fn check_update() -> String {
    let deadline = Instant::now()
        + Duration::from_millis(crate::CONFIG.updater_timeout_ms);

    // Wrap in catch_unwind as a last-resort backstop.
    // run_boot_check is designed to never panic, but transitive deps might.
    // A panic crossing the FFI boundary into Arma is undefined behaviour.
    let result = std::panic::catch_unwind(|| Updater::run_boot_check(deadline));

    match result {
        Ok(Ok(boot_result)) => boot_result.to_status_string(),
        Ok(Err(error)) => {
            log::error!("[check_update] update failed: {error}");
            format!("error:{error}")
        }
        Err(_) => {
            log::error!("[check_update] panic caught — this is a bug, please report it");
            "error:internal".into()
        }
    }
}
