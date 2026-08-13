#![deny(clippy::unwrap_used, clippy::expect_used, clippy::panic)]
#![cfg_attr(test, allow(clippy::unwrap_used, clippy::expect_used))]

//! Core updater logic shared by the Arma extension and CLI.

// The ed25519 public key used to verify the update manifest signature.
// Baked in at compile time; the matching private key is kept offline.
pub(crate) const UPDATER_PUBKEY: &[u8] =
    include_bytes!("../keys/updater.pub");

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
