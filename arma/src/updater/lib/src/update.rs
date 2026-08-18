//! Core update orchestration — boot-time fast path and CLI full path.
//!
//! `Updater::run_boot_check` is designed to fail-open: any network or
//! verification failure returns `Ok(BootCheckResult::Ok)` so that a
//! transient server outage never blocks an Arma 3 server from starting.
//!
//! `Updater::run_cli_update` is the interactive path used by the updater
//! binary; it fails hard and surfaces errors to the operator.

use crate::{
    config::Config,
    download::{extract_tar_gz, verify_sha256},
    http::{download_to, fetch_manifest},
    installed_versions,
    manifest::{self, Artifact, Component, ComponentVersion, VersionManifest},
    signing::{verification_key, verify_with_key},
    UpdaterError,
};
use semver::Version;
use std::path::Path;
use std::time::{Duration, Instant};

/// The outcome of a boot-time update check.
///
/// Returned by `Updater::run_boot_check` and converted to a short status
/// string for SQF consumption via `to_status_string`.
#[derive(Debug)]
pub enum BootCheckResult {
    /// The updater is disabled in `@esm/config.yml`.
    Disabled,
    /// No update was applied; the running version is current (or check failed
    /// safely and was suppressed).
    Ok,
    /// An update was downloaded and swapped in successfully.
    Updated {
        /// Name of the updated component (e.g. `"esm"`).
        component: String,
        /// New version string.
        version: String,
    },
    /// An update is available but a prerequisite is not yet satisfied.
    Pending {
        /// Name of the component that wants to update.
        component: String,
        /// Human-readable reason the update was deferred.
        reason: String,
    },
}

impl BootCheckResult {
    /// Convert to a human-readable status string logged to the Arma RPT via
    /// `diag_log` in the `esm_updater` preInit script.
    pub fn to_status_string(&self) -> String {
        match self {
            BootCheckResult::Ok => "No updates available.".into(),
            BootCheckResult::Disabled => "Auto-updater is disabled.".into(),
            BootCheckResult::Updated { component, version } => {
                format!("Successfully updated {component} to v{version}.")
            }
            BootCheckResult::Pending { component, reason } => {
                format!("Update pending for {component}: {reason}.")
            }
        }
    }
}

/// Which component(s) the CLI update command should touch.
#[derive(Debug, Clone, Copy)]
pub enum UpdateSelection {
    /// Update all available components.
    All,
    /// Update only the Arma 3 extension DLL/SO.
    Extension,
    /// Update only the `@esm` mod bundle.
    Mod,
    /// Update only the updater tooling itself.
    Updater,
}

/// A component whose manifest version is newer than what is installed.
///
/// Produced by `Updater::run_check`, which only ever reads.
#[derive(Debug)]
pub struct AvailableUpdate {
    /// Component name as it appears in the manifest (e.g. `"esm"`, `"@esm"`).
    pub name: String,
    /// Version currently installed, or `0.0.0` when nothing has recorded one yet.
    pub installed: Version,
    /// Version offered by the manifest.
    pub available: Version,
    /// Set when the update exists but a dependency requirement is not yet satisfied.
    pub blocked_by: Option<String>,
}

/// Everything a read-only check found.
#[derive(Debug)]
pub struct CheckOutcome {
    /// Components the manifest offers in a newer version than what is installed.
    pub available: Vec<AvailableUpdate>,

    /// Set when the manifest offers a newer CLI than the one that asked.
    ///
    /// Reported rather than installed. Replacing the running binary is deliberately left to the operator, so this is
    /// only ever a message.
    pub newer_cli: Option<Version>,
}

/// Record of a successfully updated component returned by `run_cli_update`.
#[derive(Debug)]
pub struct UpdatedComponent {
    /// Component name (e.g. `"esm"`, `"@esm"`).
    pub name: String,
    /// New version installed.
    pub version: String,
    /// Approximate wall-clock time spent on this component in milliseconds.
    pub elapsed_ms: u64,
}

/// Updater orchestrator.
///
/// All methods are associated functions (no instance state) — call them
/// directly on the type: `Updater::run_boot_check(deadline)`.
pub struct Updater;

impl Updater {
    /// Fast boot-time check: fetch the manifest, verify it, and — if a new
    /// extension version is available — download and swap it in atomically.
    ///
    /// Designed to fail-open: any non-fatal error (network, signature, parse)
    /// is logged at WARN and `Ok(BootCheckResult::Ok)` is returned so the
    /// server can still start.
    pub fn run_boot_check(
        deadline: Instant,
    ) -> Result<BootCheckResult, UpdaterError> {
        let started_at = Instant::now();

        let cfg = Config::new();
        if !cfg.updater_enabled {
            return Ok(BootCheckResult::Disabled);
        }

        // Unreadable is treated as nothing-installed here rather than as an error, because this is the fail-open
        // path and a corrupt record must not be able to stop a server from booting.
        let installed = installed_versions::load().unwrap_or_default();
        let installed_mod_ver = installed.version_of(Component::EsmMod);

        // -- Fetch manifest (fail-open) ------------------------------------
        let manifest_started_at = Instant::now();
        let (manifest_bytes, sig_bytes) =
            match fetch_manifest(&cfg.updater_url, deadline) {
                Ok(pair) => pair,
                Err(e) => {
                    log::warn!(
                        "[check_update] manifest fetch failed (fail-open): {e}"
                    );
                    return Ok(BootCheckResult::Ok);
                }
            };
        let manifest_elapsed_ms = manifest_started_at.elapsed().as_millis();

        // -- Verify signature (fail-open) ----------------------------------
        let verify_started_at = Instant::now();
        let pubkey = match verification_key() {
            Ok(key) => key,
            Err(e) => {
                log::warn!("[check_update] verification key unusable (fail-open): {e}");
                return Ok(BootCheckResult::Ok);
            }
        };
        if let Err(e) = verify_with_key(&manifest_bytes, &sig_bytes, &pubkey) {
            log::warn!(
                "[check_update] manifest signature invalid (fail-open): {e}"
            );
            return Ok(BootCheckResult::Ok);
        }
        let verify_elapsed_ms = verify_started_at.elapsed().as_millis();

        // -- Parse manifest (fail-open) ------------------------------------
        let manifest: VersionManifest =
            match serde_json::from_slice(&manifest_bytes) {
                Ok(m) => m,
                Err(e) => {
                    log::warn!(
                        "[check_update] manifest parse failed (fail-open): {e}"
                    );
                    return Ok(BootCheckResult::Ok);
                }
            };

        // -- Log informational notices ------------------------------------
        //
        // The boot path deliberately installs nothing but the extension, and only announces the rest. Two reasons, and
        // both are about the window this runs in.
        //
        // The budget is `updater_timeout_ms` (800ms by default) for the whole check, because this sits between Arma
        // starting and the server accepting players. That is enough to fetch a manifest and swap one file, not enough
        // to pull down a mod bundle.
        //
        // More importantly, swapping one dormant file is safe in a way that swapping the rest is not. The extension
        // works because Arma has not mapped `esm_x64.so` yet, so it is still just a file on disk. PBOs are already
        // being read by the engine by this point, and the updater components are what would be doing the swapping, so
        // replacing them mid-run means a process rewriting itself while it works. Those belong in the CLI path, where
        // an operator is present, the server is stopped, and a failure is recoverable by hand.
        //
        // So the owner learns an update exists on the boot they would have found out anyway, and applies it when the
        // server is down.
        if let Some(eu) = &manifest.extension_updater {
            log::info!(
                "[check_update] extension_updater {} available",
                eu.version
            );
        }
        if let Some(mu) = &manifest.mod_updater {
            log::info!("[check_update] mod_updater {} available", mu.version);
        }
        if let Some(at) = &manifest.esm_mod {
            log::info!("[check_update] @esm {} available", at.version);
        }

        // -- Check extension update ----------------------------------------
        let esm_comp = match &manifest.esm {
            None => {
                log::info!(
                    "[check_update] total={}ms (manifest={}ms verify={}ms)",
                    started_at.elapsed().as_millis(),
                    manifest_elapsed_ms,
                    verify_elapsed_ms,
                );
                return Ok(BootCheckResult::Ok);
            }
            Some(c) => c,
        };

        // The installed version has to be read off disk. This code is compiled into the updater, not the extension,
        // so its own `CARGO_PKG_VERSION` describes the wrong crate entirely, and the extension cannot be asked
        // directly because Arma has not loaded it yet.
        let current_ver = installed.version_of(Component::Esm);

        if esm_comp.version <= current_ver {
            log::info!(
                "[check_update] extension is current ({current_ver})"
            );
            return Ok(BootCheckResult::Ok);
        }

        // -- Check dependency requirements ---------------------------------
        if let Some(req) = esm_comp.requires.get("@esm")
            && !req.matches(&installed_mod_ver)
        {
            let reason = format!("@esm {installed_mod_ver} does not satisfy {req}");
            log::info!("[check_update] esm {} deferred: {reason}", esm_comp.version);
            return Ok(BootCheckResult::Pending {
                component: "esm".into(),
                reason,
            });
        }

        // -- Download and swap --------------------------------------------
        match download_and_swap_extension(esm_comp, deadline) {
            Ok(()) => {}
            Err(e) => {
                log::warn!("[check_update] extension update failed (fail-open): {e}");
                return Ok(BootCheckResult::Ok);
            }
        }

        let total_ms = started_at.elapsed().as_millis();
        log::info!(
            "[check_update] total={total_ms}ms \
             (manifest={manifest_elapsed_ms}ms verify={verify_elapsed_ms}ms)"
        );

        Ok(BootCheckResult::Updated {
            component: "esm".into(),
            version: esm_comp.version.to_string(),
        })
    }

    /// Full CLI update: fetch manifest, verify, download and install all
    /// selected components with proper dependency ordering.
    ///
    /// Unlike `run_boot_check` this fails hard on any error — the operator
    /// is present and needs to know what went wrong.
    pub fn run_cli_update(
        selection: UpdateSelection,
        manifest_url_override: Option<String>,
        running_cli: &Version,
    ) -> Result<Vec<UpdatedComponent>, UpdaterError> {
        let deadline = Instant::now() + Duration::from_secs(30);
        let cfg = Config::new().with_manifest_url(manifest_url_override);

        let manifest = load_manifest(&cfg.updater_url, deadline)?;

        // Warned about here as well as in `check`, because an operator who only ever runs `update` would otherwise
        // never hear it, and this is the component whose age affects how every other component gets installed.
        if let Some(offered) = newer_cli_than(&manifest, running_cli) {
            log::warn!(
                "[update] this updater is {running_cli}; {offered} is available and is what the manifest expects"
            );
        }

        let mut results = Vec::new();

        let installed = installed_versions::load()?;

        // Determine whether @esm should be updated before esm (dep ordering).
        let esm_needs_mod_first = manifest
            .esm
            .as_ref()
            .and_then(|e| e.requires.get("@esm"))
            .map(|req| !req.matches(&installed.version_of(Component::EsmMod)))
            .unwrap_or(false);

        let update_mod = matches!(
            selection,
            UpdateSelection::All | UpdateSelection::Mod
        );
        let update_ext = matches!(
            selection,
            UpdateSelection::All | UpdateSelection::Extension
        );
        let update_updater = matches!(
            selection,
            UpdateSelection::All | UpdateSelection::Updater
        );

        // @esm first when esm depends on it.
        if let Some(comp) = &manifest.esm_mod
            && (update_mod || (esm_needs_mod_first && update_ext))
        {
            results.push(update_mod_bundle(comp, deadline)?);
        }

        // esm extension.
        if let Some(comp) = &manifest.esm
            && update_ext
        {
            results.push(update_esm_extension(comp, deadline)?);
        }

        // Updater components.
        if update_updater {
            if let Some(comp) = &manifest.extension_updater {
                results.push(update_updater_extension(comp, deadline)?);
            }

            if let Some(comp) = &manifest.mod_updater {
                results.push(update_mod_updater_pbo(comp, deadline)?);
            }
        }

        Ok(results)
    }

    /// Report which components the manifest offers in a newer version than what is installed.
    ///
    /// Reads only. Nothing is downloaded, nothing on disk is touched, and the manifest URL override is honoured so a
    /// manifest can be inspected without committing to it.
    ///
    /// `running_cli` has to be supplied by the caller because only the binary knows its own version; this crate is
    /// compiled into both the CLI and the Arma extension, so its own `CARGO_PKG_VERSION` describes neither.
    pub fn run_check(
        manifest_url_override: Option<String>,
        running_cli: &Version,
    ) -> Result<CheckOutcome, UpdaterError> {
        let deadline = Instant::now() + Duration::from_secs(30);
        let cfg = Config::new().with_manifest_url(manifest_url_override);

        let manifest = load_manifest(&cfg.updater_url, deadline)?;
        let installed = installed_versions::load()?;

        let newer_cli = newer_cli_than(&manifest, running_cli);
        let mut available = Vec::new();

        for component in Component::ALL {
            let Some(offered) = manifest.get(component) else {
                continue;
            };

            let installed_ver = installed.version_of(component);
            if offered.version <= installed_ver {
                continue;
            }

            // A dependency the operator has not satisfied yet is still an available update; it just cannot be taken
            // on its own. Reporting it as blocked rather than hiding it is the difference between "nothing to do"
            // and "update the mod first". A requirement naming something this updater does not install cannot be
            // evaluated, so it is reported as blocking rather than quietly passed.
            let blocked_by = offered
                .requires
                .iter()
                .find(|(name, req)| match Component::from_key(name) {
                    Some(dependency) => !req.matches(&installed.version_of(dependency)),
                    None => true,
                })
                .map(|(name, req)| format!("{name} {req}"));

            available.push(AvailableUpdate {
                name: component.key().to_string(),
                installed: installed_ver,
                available: offered.version.clone(),
                blocked_by,
            });
        }

        Ok(CheckOutcome { available, newer_cli })
    }
}

/// The artifact this machine should download for `comp`.
///
/// A release that offers nothing for this platform is an error rather than a silent skip: the caller only gets here
/// after deciding an update is wanted, so "there is no file for you" is information the operator needs.
fn artifact_for(comp: &ComponentVersion) -> Result<&Artifact, UpdaterError> {
    comp.artifact().ok_or_else(|| {
        UpdaterError::Parse(format!(
            "release {} offers no artifact for {}",
            comp.version,
            manifest::current_platform()
        ))
    })
}

/// The manifest's CLI version, when it is newer than `running`.
fn newer_cli_than(manifest: &VersionManifest, running: &Version) -> Option<Version> {
    manifest
        .updater_cli
        .as_ref()
        .map(|entry| entry.version.clone())
        .filter(|offered| offered > running)
}

// ── Shared helpers ────────────────────────────────────────────────────────────

/// Fetch, verify, and parse the version manifest from `url` within `deadline`.
///
/// Used by both the boot check and CLI update paths.
fn load_manifest(
    url: &str,
    deadline: Instant,
) -> Result<VersionManifest, UpdaterError> {
    let (manifest_bytes, sig_bytes) = fetch_manifest(url, deadline)?;
    verify_with_key(&manifest_bytes, &sig_bytes, &verification_key()?)?;
    serde_json::from_slice(&manifest_bytes)
        .map_err(|e| UpdaterError::Parse(e.to_string()))
}

/// Atomically swap `source` into `dest` using a `.backup` intermediate.
///
/// On success the backup is removed. On failure the backup is restored.
fn swap_file(source: &Path, dest: &Path) -> Result<(), UpdaterError> {
    let backup = dest.with_file_name(format!(
        "{}.backup",
        dest.file_name()
            .unwrap_or_default()
            .to_string_lossy()
    ));
    if dest.exists() {
        std::fs::rename(dest, &backup)?;
    }
    match std::fs::rename(source, dest) {
        Ok(()) => {
            let _ = std::fs::remove_file(&backup);
            Ok(())
        }
        Err(e) => {
            if backup.exists() {
                let _ = std::fs::rename(&backup, dest);
            }
            Err(UpdaterError::Io(e))
        }
    }
}

/// Download the ESM extension artifact, verify its checksum, and swap it in.
///
/// Creates `@esm/temp/` if needed, downloads the artifact, checks the SHA256,
/// then calls `swap_file` to atomically replace the live extension.
fn download_and_swap_extension(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<(), UpdaterError> {
    let download_started_at = Instant::now();
    let temp_dir = Path::new("@esm/temp");
    std::fs::create_dir_all(temp_dir)?;
    let temp_file = temp_dir.join("esm_update");

    let artifact = artifact_for(comp)?;
    download_to(&artifact.url, &temp_file, deadline)?;
    let download_elapsed_ms = download_started_at.elapsed().as_millis();

    let checksum_started_at = Instant::now();
    if let Err(e) = verify_sha256(&temp_file, &artifact.sha256) {
        let _ = std::fs::remove_file(&temp_file);
        return Err(e);
    }
    let checksum_elapsed_ms = checksum_started_at.elapsed().as_millis();

    let swap_started_at = Instant::now();
    let filename = esm_extension_filename();
    let dest = Path::new("@esm").join(filename);
    swap_file(&temp_file, &dest)?;
    let swap_elapsed_ms = swap_started_at.elapsed().as_millis();

    record_installed(Component::Esm, &comp.version);

    log::info!(
        "[check_update] download={download_elapsed_ms}ms \
         checksum={checksum_elapsed_ms}ms swap={swap_elapsed_ms}ms"
    );

    Ok(())
}

/// Record the version just installed, downgrading a write failure to a warning.
///
/// The install is the part that matters and it has already happened by the time this runs. Failing here would report
/// that the update did not happen when it did; the real cost of an unrecorded version is one redundant download on
/// the next check, which the signature and checksum still guard.
fn record_installed(component: Component, version: &Version) {
    if let Err(e) = installed_versions::record(component, version) {
        log::warn!(
            "[update] {} updated to {version} but recording the version failed: {e}",
            component.key()
        );
    }
}

// ── CLI per-component update functions ───────────────────────────────────────

fn update_mod_bundle(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let temp_dir = Path::new("@esm/temp/addons_stage");
    let archive = Path::new("@esm/temp/at_esm_update.tar.gz");
    let artifact = artifact_for(comp)?;
    download_to(&artifact.url, archive, deadline)?;
    verify_sha256(archive, &artifact.sha256)?;
    extract_tar_gz(archive, temp_dir)?;

    let addons = Path::new("@esm/addons");
    let backup = Path::new("@esm/addons.backup");
    if addons.exists() {
        std::fs::rename(addons, backup)?;
    }
    std::fs::rename(temp_dir, addons)?;
    record_installed(Component::EsmMod, &comp.version);
    if backup.exists() {
        let _ = std::fs::remove_dir_all(backup);
    }

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] @esm | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "@esm".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

fn update_esm_extension(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let filename = esm_extension_filename();
    let temp_dir = Path::new("@esm/temp");
    std::fs::create_dir_all(temp_dir)?;
    let temp_file = temp_dir.join("esm_update");
    let artifact = artifact_for(comp)?;
    download_to(&artifact.url, &temp_file, deadline)?;
    verify_sha256(&temp_file, &artifact.sha256)?;

    let dest = Path::new("@esm").join(filename);
    swap_file(&temp_file, &dest)?;
    record_installed(Component::Esm, &comp.version);

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] esm | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "esm".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

/// Install the updater's own Arma extension over the copy the server loads at boot.
///
/// The destination has to be the exact filename Arma resolves `"esm_updater" callExtension` to, or the download
/// succeeds, the version is recorded, and the next boot still runs the old binary.
fn update_updater_extension(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let dest = Path::new("@esm").join(updater_extension_filename());
    let temp = Path::new("@esm/temp/ext_updater");
    std::fs::create_dir_all(Path::new("@esm/temp"))?;
    let artifact = artifact_for(comp)?;
    download_to(&artifact.url, temp, deadline)?;
    verify_sha256(temp, &artifact.sha256)?;
    swap_file(temp, &dest)?;
    record_installed(Component::ExtensionUpdater, &comp.version);

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] extension_updater | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "extension_updater".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

/// Install the updater's own addon into the folder Arma loads PBOs from.
///
/// `@esm/addons` is created when it is missing, since updating only the updater is a valid thing to ask for on an
/// install that has nothing else yet.
fn update_mod_updater_pbo(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let dest = Path::new("@esm/addons/esm_updater.pbo");
    let temp = Path::new("@esm/temp/mod_updater.pbo");
    std::fs::create_dir_all(Path::new("@esm/temp"))?;
    std::fs::create_dir_all(Path::new("@esm/addons"))?;
    let artifact = artifact_for(comp)?;
    download_to(&artifact.url, temp, deadline)?;
    verify_sha256(temp, &artifact.sha256)?;
    swap_file(temp, dest)?;
    record_installed(Component::ModUpdater, &comp.version);

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] mod_updater | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "mod_updater".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

// ── Utilities ─────────────────────────────────────────────────────────────────

/// Return the platform-appropriate filename for the updater's own Arma extension.
///
/// Named to match what `bin/package` ships and what the manifest offers per platform, since this is the file the
/// `esm_updater` addon calls into during `preInit`.
fn updater_extension_filename() -> &'static str {
    if cfg!(target_os = "windows") {
        if cfg!(target_pointer_width = "64") {
            "esm_updater_x64.dll"
        } else {
            "esm_updater.dll"
        }
    } else if cfg!(target_pointer_width = "64") {
        "esm_updater_x64.so"
    } else {
        "esm_updater.so"
    }
}

/// Return the platform-appropriate filename for the ESM Arma extension.
fn esm_extension_filename() -> &'static str {
    if cfg!(target_os = "windows") {
        if cfg!(target_pointer_width = "64") {
            "esm_x64.dll"
        } else {
            "esm.dll"
        }
    } else if cfg!(target_pointer_width = "64") {
        "esm_x64.so"
    } else {
        "esm.so"
    }
}
