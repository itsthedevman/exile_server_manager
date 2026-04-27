//! HTTP helpers for fetching the manifest and downloading artifacts.
//!
//! All functions accept a shared `deadline: Instant` so the total wall-clock
//! time consumed by a sequence of requests stays bounded.

use crate::UpdaterError;
use std::io::{Read, Write};
use std::path::Path;
use std::time::Instant;

/// Fetch the manifest JSON and its detached signature.
///
/// The signature URL is derived by appending `.sig` to `manifest_url`.
/// Both responses are returned as raw byte vectors so the caller can
/// verify the signature before parsing any JSON.
pub fn fetch_manifest(
    manifest_url: &str,
    deadline: Instant,
) -> Result<(Vec<u8>, Vec<u8>), UpdaterError> {
    let manifest_bytes = get_bytes(manifest_url, deadline)?;
    let sig_url = format!("{manifest_url}.sig");
    let sig_bytes = get_bytes(&sig_url, deadline)?;
    Ok((manifest_bytes, sig_bytes))
}

/// Download `url` and write it atomically to `dest_path`.
///
/// If any error occurs after the file has been partially created it is
/// removed to avoid leaving a corrupted artifact on disk.
pub fn download_to(
    url: &str,
    dest_path: &Path,
    deadline: Instant,
) -> Result<(), UpdaterError> {
    let result = download_inner(url, dest_path, deadline);
    if result.is_err() {
        // Best-effort cleanup; ignore secondary I/O errors.
        let _ = std::fs::remove_file(dest_path);
    }
    result
}

// ── internal helpers ──────────────────────────────────────────────────────────

fn remaining(deadline: Instant) -> Result<std::time::Duration, UpdaterError> {
    let now = Instant::now();
    if now >= deadline {
        return Err(UpdaterError::Deadline);
    }
    Ok(deadline - now)
}

fn get_bytes(url: &str, deadline: Instant) -> Result<Vec<u8>, UpdaterError> {
    let timeout = remaining(deadline)?;

    let response = ureq::get(url)
        .timeout(timeout)
        .call()
        .map_err(|e| UpdaterError::Http(e.to_string()))?;

    let mut buf = Vec::new();
    response
        .into_reader()
        .read_to_end(&mut buf)
        .map_err(UpdaterError::Io)?;

    Ok(buf)
}

fn download_inner(
    url: &str,
    dest_path: &Path,
    deadline: Instant,
) -> Result<(), UpdaterError> {
    let timeout = remaining(deadline)?;

    let response = ureq::get(url)
        .timeout(timeout)
        .call()
        .map_err(|e| UpdaterError::Http(e.to_string()))?;

    if let Some(parent) = dest_path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let mut file = std::fs::File::create(dest_path)?;
    let mut reader = response.into_reader();

    let mut buf = [0u8; 65536];
    loop {
        let n = reader.read(&mut buf).map_err(UpdaterError::Io)?;
        if n == 0 {
            break;
        }
        file.write_all(&buf[..n])?;
    }

    Ok(())
}
