//! Read and write the `@esm/version` sidecar file.
//!
//! This file contains a single line with the installed mod's semver string.
//! It is written after a successful mod update so subsequent boots can
//! detect whether the mod is new enough to satisfy extension requirements.

use crate::UpdaterError;
use semver::Version;
use std::fs;

/// Read the installed mod version from `@esm/version`.
///
/// Returns `0.0.0` when the file is absent (i.e. the mod has never been
/// updated by this updater, so we assume a very old baseline).
/// Returns an error only when the file exists but contains invalid semver.
pub fn read_installed_mod_version() -> Result<Version, UpdaterError> {
    let path = std::path::Path::new("@esm/version");

    let contents = match fs::read_to_string(path) {
        Ok(s) => s,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            return Ok(Version::new(0, 0, 0));
        }
        Err(e) => return Err(UpdaterError::Io(e)),
    };

    let trimmed = contents.trim();
    Version::parse(trimmed)
        .map_err(|e| UpdaterError::Parse(format!("@esm/version: {e}")))
}

/// Write the installed mod version to `@esm/version`.
///
/// Overwrites any existing file. Creates parent directories if needed
/// (though `@esm/` should already exist by the time this is called).
pub fn write_version(version: &Version) -> Result<(), UpdaterError> {
    let path = std::path::Path::new("@esm/version");

    // Ensure parent dir exists
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    fs::write(path, format!("{version}\n"))?;
    Ok(())
}
