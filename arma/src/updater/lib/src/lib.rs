#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)]
#![cfg_attr(test, allow(clippy::unwrap_used, clippy::expect_used))]

//! Core updater logic shared by the Arma extension and CLI.

// The ed25519 public key used to verify the update manifest signature. Chosen at compile time by build.rs, which
// stages it in OUT_DIR; the matching private key is kept offline.
pub(crate) const UPDATER_PUBKEY: &[u8] =
    include_bytes!(concat!(env!("OUT_DIR"), "/verification_key.der"));

/// Whether this build verifies manifests against the key committed with the crate.
///
/// False means the build was pointed at another key and will not accept a manifest signed with the default one.
pub const USES_DEFAULT_KEY: bool = cfg!(default_key);

/// Which signing key this build accepts manifests from.
///
/// A build on a key other than the default accepts a different set of manifests entirely, so it says so on every
/// startup. That turns a mis-built binary into an obvious line in the log rather than a server that quietly stops
/// updating.
pub fn verification_key_label() -> String {
    let fingerprint = env!("ESM_UPDATER_KEY_FINGERPRINT");

    if USES_DEFAULT_KEY {
        format!("default key {fingerprint}")
    } else {
        format!("custom key {fingerprint}")
    }
}

pub mod config;
pub mod download;
pub mod error;
pub mod http;
pub mod installed_versions;
pub mod manifest;
pub mod signing;
pub mod update;

pub use error::UpdaterError;
pub use manifest::Component;
pub use update::{
    AvailableUpdate, BootCheckResult, CheckOutcome, UpdateSelection, UpdatedComponent, Updater,
};
