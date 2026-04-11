//! Arma-rs command registration for the updater extension.

use arma_rs::Extension;

mod check_update;
use check_update::check_update;

/// Register all extension commands and return the built extension.
pub fn register() -> Extension {
    Extension::build()
        .version(env!("CARGO_PKG_VERSION").into())
        .command("check_update", check_update)
        .finish()
}
