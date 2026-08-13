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

/// The four things the updater knows how to install.
///
/// Used as the shared vocabulary between the remote manifest and the local record of what is installed, so both
/// documents key their entries the same way.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Component {
    /// The Arma 3 extension binary.
    Esm,
    /// The `@esm` mod bundle.
    EsmMod,
    /// The updater's own extension.
    ExtensionUpdater,
    /// The updater's mod-side PBO.
    ModUpdater,
}

impl Component {
    /// Every component, in dependency order: the mod before the extension that may require it.
    pub const ALL: [Component; 4] = [
        Component::EsmMod,
        Component::Esm,
        Component::ExtensionUpdater,
        Component::ModUpdater,
    ];

    /// Resolve a manifest key back to a component, or `None` for a name this updater does not know how to install.
    pub fn from_key(key: &str) -> Option<Component> {
        Component::ALL.into_iter().find(|component| component.key() == key)
    }

    /// The component's name as it appears in both the manifest and the installed-versions record.
    pub fn key(&self) -> &'static str {
        match self {
            Component::Esm => "esm",
            Component::EsmMod => "@esm",
            Component::ExtensionUpdater => "extension_updater",
            Component::ModUpdater => "mod_updater",
        }
    }
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
    pub esm_mod: Option<ComponentVersion>,

    /// The extension-side updater component.
    pub extension_updater: Option<ComponentVersion>,

    /// The mod-side updater PBO.
    pub mod_updater: Option<ComponentVersion>,
}

impl VersionManifest {
    /// The manifest's entry for `component`, if it offers one.
    pub fn get(&self, component: Component) -> Option<&ComponentVersion> {
        match component {
            Component::Esm => self.esm.as_ref(),
            Component::EsmMod => self.esm_mod.as_ref(),
            Component::ExtensionUpdater => self.extension_updater.as_ref(),
            Component::ModUpdater => self.mod_updater.as_ref(),
        }
    }
}
