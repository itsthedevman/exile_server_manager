//! The record of what the updater has installed, kept at `@esm/installed_versions.yml`.
//!
//! This file exists because nothing on disk can be asked its own version. The mod is a directory of PBOs, the
//! extension has not been loaded by Arma yet when the boot check runs, and the updater's own components are the ones
//! doing the asking. Writing the version down at install time is the only way a later check knows what it is looking
//! at.
//!
//! One file rather than a sidecar per component, so an operator finding it in `@esm/` has one thing to understand
//! instead of four. It is keyed by the same component names the remote manifest uses, so the two documents read as
//! two halves of the same conversation: the manifest says what is offered, this says what is here.

use crate::UpdaterError;
use crate::manifest::Component;
use semver::Version;
use serde::{Deserialize, Serialize};
use std::path::Path;

/// Location of the record, relative to the server root.
const PATH: &str = "@esm/installed_versions.yml";

/// Header written above the data, for whoever opens the file wondering what it is.
const PREAMBLE: &str = "\
# Written by the ESM updater. Records the version of each component currently installed so the next
# update check knows what it is comparing against.
#
# Safe to delete. The updater treats a missing entry as \"very old\", so removing this file causes the
# next check to reinstall everything and write it out again.
";

/// Versions currently installed, as last recorded by the updater.
///
/// Every field is optional because a component that has never been installed by the updater has no recorded version,
/// which is different from having version zero. Callers get `0.0.0` from `version_of`, which is the value that makes
/// an absent component compare as older than anything the manifest can offer.
#[derive(Debug, Default, Serialize, Deserialize)]
pub struct InstalledVersions {
    /// The Arma 3 extension binary.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub esm: Option<Version>,

    /// The `@esm` mod bundle.
    #[serde(rename = "@esm", default, skip_serializing_if = "Option::is_none")]
    pub esm_mod: Option<Version>,

    /// The updater's own extension.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub extension_updater: Option<Version>,

    /// The updater's mod-side PBO.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mod_updater: Option<Version>,
}

impl InstalledVersions {
    /// The recorded version of `component`, or `0.0.0` when nothing has been recorded for it.
    pub fn version_of(&self, component: Component) -> Version {
        self.slot(component).clone().unwrap_or_else(|| Version::new(0, 0, 0))
    }

    fn slot(&self, component: Component) -> &Option<Version> {
        match component {
            Component::Esm => &self.esm,
            Component::EsmMod => &self.esm_mod,
            Component::ExtensionUpdater => &self.extension_updater,
            Component::ModUpdater => &self.mod_updater,
        }
    }

    fn slot_mut(&mut self, component: Component) -> &mut Option<Version> {
        match component {
            Component::Esm => &mut self.esm,
            Component::EsmMod => &mut self.esm_mod,
            Component::ExtensionUpdater => &mut self.extension_updater,
            Component::ModUpdater => &mut self.mod_updater,
        }
    }
}

/// Load the record, treating a missing file as "nothing installed yet".
///
/// A missing file and a corrupt one are deliberately different outcomes. Missing is a normal state with a sensible
/// answer. Corrupt means something wrote garbage where versions belong, and quietly substituting "nothing installed"
/// would turn that into a silent reinstall of every component rather than a visible error.
pub fn load() -> Result<InstalledVersions, UpdaterError> {
    let contents = match std::fs::read_to_string(Path::new(PATH)) {
        Ok(contents) => contents,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(InstalledVersions::default()),
        Err(e) => return Err(UpdaterError::Io(e)),
    };

    serde_yaml::from_str(&contents).map_err(|e| UpdaterError::Parse(format!("{PATH}: {e}")))
}

/// Record `version` as installed for `component`, leaving every other entry as it was.
///
/// Reads the current file first so that installing one component never erases the record of the others.
pub fn record(component: Component, version: &Version) -> Result<(), UpdaterError> {
    let mut versions = load().unwrap_or_default();
    *versions.slot_mut(component) = Some(version.clone());
    save(&versions)
}

fn save(versions: &InstalledVersions) -> Result<(), UpdaterError> {
    let path = Path::new(PATH);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let body = serde_yaml::to_string(versions).map_err(|e| UpdaterError::Parse(e.to_string()))?;

    std::fs::write(path, format!("{PREAMBLE}\n{body}"))?;
    Ok(())
}
