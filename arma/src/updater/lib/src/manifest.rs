//! Manifest types deserialized from the JSON version document.
//!
//! The manifest lists available versions for each ESM component along with
//! download URLs, checksums, and optional dependency requirements.

use std::collections::BTreeMap;

/// Version record for a single ESM component in the manifest.
#[derive(Debug, serde::Deserialize)]
pub struct ComponentVersion {
    /// The semantic version of this component release.
    pub version: semver::Version,

    /// URL from which to download the release artifact.
    pub url: String,

    /// Lowercase hex-encoded SHA-256 of the artifact at `url`.
    pub sha256: String,

    /// Human-readable release date (e.g. "2024-01-15"); informational only.
    pub release_date: Option<String>,

    /// Human-readable change summary; informational only.
    pub changes: Option<String>,

    /// Version requirements on other components.
    ///
    /// Keys are component names (e.g. `"@esm"`); values are semver
    /// requirement strings (e.g. `">=1.2.0"`). If any requirement is unmet
    /// the update is deferred.
    #[serde(default)]
    pub requires: BTreeMap<String, semver::VersionReq>,
}

/// Top-level version manifest.
///
/// Each field corresponds to a named ESM component; absent keys mean
/// no update is available for that component.
#[derive(Debug, serde::Deserialize)]
pub struct VersionManifest {
    /// The Arma 3 extension DLL/SO (e.g. `esm_x64.so`).
    pub esm: Option<ComponentVersion>,

    /// The Arma 3 mod PBO bundle.
    #[serde(rename = "@esm")]
    pub at_esm: Option<ComponentVersion>,

    /// The extension-side updater component.
    pub extension_updater: Option<ComponentVersion>,

    /// The mod-side updater PBO.
    pub mod_updater: Option<ComponentVersion>,
}
