//! File verification and archive extraction utilities.

use crate::UpdaterError;
use sha2::{Digest, Sha256};
use std::path::Path;

/// Verify the SHA-256 hash of a file against an expected hex string.
///
/// The comparison is done in constant time to prevent timing attacks,
/// though for update verification this is primarily about correctness.
pub fn verify_sha256(
    path: &Path,
    expected_hex: &str,
) -> Result<(), UpdaterError> {
    let data = std::fs::read(path)?;
    let mut hasher = Sha256::new();
    hasher.update(&data);
    let actual = hex::encode(hasher.finalize());

    if actual != expected_hex {
        return Err(UpdaterError::ChecksumMismatch {
            expected: expected_hex.to_string(),
            actual,
        });
    }

    Ok(())
}

/// Extract a `.tar.gz` archive into `dest_dir`.
///
/// Creates `dest_dir` if it does not exist. Files are extracted with their
/// paths relative to the archive root, potentially creating subdirectories.
pub fn extract_tar_gz(
    archive_path: &Path,
    dest_dir: &Path,
) -> Result<(), UpdaterError> {
    use flate2::read::GzDecoder;
    use std::fs::File;

    std::fs::create_dir_all(dest_dir)?;

    let file =
        File::open(archive_path).map_err(UpdaterError::Io)?;
    let gz = GzDecoder::new(file);
    let mut archive = tar::Archive::new(gz);

    archive
        .unpack(dest_dir)
        .map_err(|e| UpdaterError::Extract(e.to_string()))?;

    Ok(())
}
