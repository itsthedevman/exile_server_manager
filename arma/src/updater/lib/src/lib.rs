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
pub mod manifest;
pub mod signing;
pub mod update;
pub mod version_file;

pub use error::UpdaterError;
pub use update::{
    BootCheckResult, UpdateSelection, UpdatedComponent, Updater,
};
