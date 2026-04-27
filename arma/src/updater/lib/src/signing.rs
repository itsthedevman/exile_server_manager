//! Ed25519 signature verification for the update manifest.
//!
//! The production public key is DER-encoded SubjectPublicKeyInfo and is baked
//! into the binary at compile time via `include_bytes!`. Tests use an
//! ephemeral keypair generated at runtime so the private key is never stored.

use crate::{UpdaterError, UPDATER_PUBKEY};
use ed25519_dalek::{Signature, VerifyingKey};

/// Verify that `sig_bytes` is a valid ed25519 signature over `manifest_bytes`
/// using the baked-in production public key.
///
/// The production key is stored as DER-encoded SubjectPublicKeyInfo (44 bytes).
/// The raw 32-byte key material is the last 32 bytes of that encoding.
pub fn verify_manifest(
    manifest_bytes: &[u8],
    sig_bytes: &[u8],
) -> Result<(), UpdaterError> {
    // DER SubjectPublicKeyInfo for ed25519 is a fixed 12-byte prefix + 32-byte key.
    let raw = extract_raw_pubkey(UPDATER_PUBKEY)?;
    verify_with_key(manifest_bytes, sig_bytes, raw)
}

/// Verify using an explicitly provided raw 32-byte ed25519 public key.
///
/// Separating the raw-key path from the DER-extraction path lets tests supply
/// their own ephemeral key without having to re-encode it as DER.
/// Also used by integration tests via `updater_lib::signing::verify_with_key`.
pub fn verify_with_key(
    bytes: &[u8],
    sig_bytes: &[u8],
    pubkey_bytes: &[u8],
) -> Result<(), UpdaterError> {
    use ed25519_dalek::Verifier;

    let key_arr: [u8; 32] = pubkey_bytes
        .try_into()
        .map_err(|_| UpdaterError::BadSignature)?;

    let sig_arr: [u8; 64] = sig_bytes
        .try_into()
        .map_err(|_| UpdaterError::BadSignature)?;

    let verifying_key =
        VerifyingKey::from_bytes(&key_arr).map_err(|_| UpdaterError::BadSignature)?;

    let signature =
        Signature::from_bytes(&sig_arr);

    verifying_key
        .verify(bytes, &signature)
        .map_err(|_| UpdaterError::BadSignature)
}

/// Extract the raw 32-byte key material from a DER SubjectPublicKeyInfo blob.
///
/// The DER encoding for ed25519 is a fixed 12-byte header followed by 32 bytes
/// of key material, for a total of 44 bytes.
pub(crate) fn extract_raw_pubkey(der: &[u8]) -> Result<&[u8], UpdaterError> {
    if der.len() < 32 {
        return Err(UpdaterError::BadSignature);
    }
    Ok(&der[der.len() - 32..])
}

/// Generate a fresh ed25519 keypair, sign `data`, and return
/// `(raw_pubkey_32_bytes, sig_64_bytes)`.
///
/// Intended for test use only — do not call from production paths.
/// Available in all compilation modes so integration tests (which are
/// separate crates) can import it.
#[cfg(any(test, feature = "testing"))]
pub fn sign_for_test(data: &[u8]) -> (Vec<u8>, Vec<u8>) {
    use ed25519_dalek::Signer;
    use ed25519_dalek::SigningKey;
    use rand::rngs::OsRng;

    let signing_key = SigningKey::generate(&mut OsRng);
    let sig = signing_key.sign(data);
    let verifying_key = signing_key.verifying_key();
    (verifying_key.as_bytes().to_vec(), sig.to_bytes().to_vec())
}
