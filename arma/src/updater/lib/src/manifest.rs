//! Manifest types deserialized from the JSON version document.
//!
//! The manifest lists available versions for each ESM component along with
//! download URLs, checksums, and optional dependency requirements.

use std::collections::BTreeMap;

/// The platform key an artifact is filed under.
///
/// Arma ships 32- and 64-bit servers on both Linux and Windows, and the extension is a native binary, so one release
/// is four different files. They are distinguished here rather than by publishing four manifests, so that a server
/// fetches and verifies exactly one signed document no matter what it runs on.
pub const PLATFORM_ANY: &str = "any";

/// The platform key for the machine this code was compiled for.
///
/// Components that ship one file for everyone (the mod bundle, the mod-side PBO) are filed under `any` instead.
pub fn current_platform() -> &'static str {
    if cfg!(target_os = "windows") {
        if cfg!(target_pointer_width = "64") {
            "windows-x64"
        } else {
            "windows-x86"
        }
    } else if cfg!(target_pointer_width = "64") {
        "linux-x64"
    } else {
        "linux-x86"
    }
}

/// A downloadable file and the checksum it has to match.
#[derive(Debug, Clone, serde::Serialize, serde::Deserialize)]
pub struct Artifact {
    /// Absolute URL to download from. Relative paths are not resolved anywhere, so this must be fully qualified.
    pub url: String,

    /// Lowercase hex-encoded SHA-256 of the file at `url`.
    pub sha256: String,
}

/// Version record for a single ESM component in the manifest.
#[derive(Debug, serde::Serialize, serde::Deserialize)]
pub struct ComponentVersion {
    /// The semantic version of this component release.
    pub version: semver::Version,

    /// Downloadable files for this release, keyed by platform (or `any` when one file serves everyone).
    ///
    /// A platform absent from this map is simply not offered this release, which is how a manifest declines to ship
    /// something to, say, 32-bit Windows without having to describe the omission.
    #[serde(default)]
    pub artifacts: BTreeMap<String, Artifact>,

    /// Human-readable release date (e.g. "2024-01-15"); informational only.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub release_date: Option<String>,

    /// Human-readable change summary; informational only.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub changes: Option<String>,

    /// Version requirements on other components.
    ///
    /// Keys are component names (e.g. `"@esm"`); values are semver
    /// requirement strings (e.g. `">=1.2.0"`). If any requirement is unmet
    /// the update is deferred.
    #[serde(default, skip_serializing_if = "BTreeMap::is_empty")]
    pub requires: BTreeMap<String, semver::VersionReq>,
}

impl ComponentVersion {
    /// The artifact this machine should download, if this release offers one for it.
    ///
    /// An exact platform match wins; `any` covers the components that ship a single file for every server.
    pub fn artifact(&self) -> Option<&Artifact> {
        self.artifacts
            .get(current_platform())
            .or_else(|| self.artifacts.get(PLATFORM_ANY))
    }
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
#[derive(Debug, Default, serde::Serialize, serde::Deserialize)]
pub struct VersionManifest {
    /// The Arma 3 extension DLL/SO (e.g. `esm_x64.so`).
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub esm: Option<ComponentVersion>,

    /// The Arma 3 mod PBO bundle.
    #[serde(rename = "@esm")]
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub esm_mod: Option<ComponentVersion>,

    /// The extension-side updater component.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub extension_updater: Option<ComponentVersion>,

    /// The mod-side updater PBO.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mod_updater: Option<ComponentVersion>,

    /// The operator-facing updater CLI.
    ///
    /// Advisory only, which is why it is not a `Component`: the CLI is the running process during an update, and
    /// nothing here installs it. It exists so a stale CLI can be reported to the operator instead of silently
    /// carrying on, since an old updater is the one component whose bugs affect every other component's install.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub updater_cli: Option<ComponentVersion>,
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
