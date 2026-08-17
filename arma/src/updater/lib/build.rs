//! Chooses which ed25519 public key this build verifies manifests against.
//!
//! The default is the key committed alongside this crate. Setting `ESM_UPDATER_PUBKEY_PATH` to another DER public key
//! builds against that one instead, and the two are mutually exclusive: neither will accept a manifest signed for
//! the other. The chosen key is copied into `OUT_DIR` so the crate can `include_bytes!` a fixed path regardless of
//! which one won.

use std::path::PathBuf;

const OVERRIDE_VAR: &str = "ESM_UPDATER_PUBKEY_PATH";
const DEFAULT_KEY: &str = "keys/updater.pub";

/// A DER SubjectPublicKeyInfo for ed25519 is a fixed 12-byte header followed by 32 bytes of key material.
const DER_LEN: usize = 44;

fn main() {
    println!("cargo::rerun-if-env-changed={OVERRIDE_VAR}");
    println!("cargo::rerun-if-changed={DEFAULT_KEY}");
    println!("cargo::rustc-check-cfg=cfg(default_key)");

    let override_path = std::env::var(OVERRIDE_VAR).ok().filter(|path| !path.is_empty());

    let (source, is_default) = match override_path {
        Some(path) => {
            let path = PathBuf::from(path);

            // Build scripts run with the crate root as their working directory, so a relative override resolves
            // against src/updater/lib rather than wherever it was typed. Saying so beats a not-found error naming a
            // path that plainly exists.
            if path.is_relative() {
                panic!("{OVERRIDE_VAR} must be an absolute path, got {}", path.display());
            }

            println!("cargo::rerun-if-changed={}", path.display());
            (path, false)
        }
        None => (PathBuf::from(DEFAULT_KEY), true),
    };

    let key = match std::fs::read(&source) {
        Ok(key) => key,
        Err(e) => panic!("cannot read the verification key at {}: {e}", source.display()),
    };

    // Catching the wrong file here beats shipping a binary that rejects every manifest it is ever offered.
    if key.len() != DER_LEN {
        panic!(
            "{} is {} bytes; an ed25519 DER public key is {DER_LEN}",
            source.display(),
            key.len()
        );
    }

    let out_dir = match std::env::var_os("OUT_DIR") {
        Some(dir) => PathBuf::from(dir),
        None => panic!("OUT_DIR is not set; this only runs as a cargo build script"),
    };

    if let Err(e) = std::fs::write(out_dir.join("verification_key.der"), &key) {
        panic!("cannot stage the verification key: {e}");
    }

    println!("cargo::rustc-env=ESM_UPDATER_KEY_FINGERPRINT={}", fingerprint(&key));

    if is_default {
        println!("cargo::rustc-cfg=default_key");
    }
}

/// A short, stable label for a key, so a log line can say which one a build is on.
///
/// The tail of the public key is itself public, so there is nothing to protect here; it only has to be enough to
/// tell two keys apart at a glance.
fn fingerprint(der: &[u8]) -> String {
    der[der.len() - 4..].iter().map(|byte| format!("{byte:02x}")).collect()
}
