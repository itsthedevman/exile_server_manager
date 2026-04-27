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
    manifest::{ComponentVersion, VersionManifest},
    signing::{extract_raw_pubkey, verify_with_key},
    version_file,
    UpdaterError, UPDATER_PUBKEY,
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

        // Read installed mod version (missing = 0.0.0).
        let installed_mod_ver =
            version_file::read_installed_mod_version().unwrap_or_else(|_| {
                Version::new(0, 0, 0)
            });

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
        let production_pubkey = extract_raw_pubkey(UPDATER_PUBKEY)
            .unwrap_or(&UPDATER_PUBKEY[UPDATER_PUBKEY.len().saturating_sub(32)..]);
        if let Err(e) =
            verify_with_key(&manifest_bytes, &sig_bytes, production_pubkey)
        {
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
        if let Some(eu) = &manifest.extension_updater {
            log::info!(
                "[check_update] extension_updater {} available",
                eu.version
            );
        }
        if let Some(mu) = &manifest.mod_updater {
            log::info!("[check_update] mod_updater {} available", mu.version);
        }
        if let Some(at) = &manifest.at_esm {
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

        let current_ver: Version =
            match Version::parse(env!("CARGO_PKG_VERSION")) {
                Ok(v) => v,
                Err(_) => {
                    return Ok(BootCheckResult::Ok);
                }
            };

        if esm_comp.version <= current_ver {
            log::info!(
                "[check_update] extension is current ({current_ver})"
            );
            return Ok(BootCheckResult::Ok);
        }

        // -- Check dependency requirements ---------------------------------
        if let Some(req) = esm_comp.requires.get("@esm") {
            if !req.matches(&installed_mod_ver) {
                let reason = format!(
                    "@esm {installed_mod_ver} does not satisfy {req}"
                );
                log::info!(
                    "[check_update] esm {} deferred: {reason}",
                    esm_comp.version
                );
                return Ok(BootCheckResult::Pending {
                    component: "esm".into(),
                    reason,
                });
            }
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
    ) -> Result<Vec<UpdatedComponent>, UpdaterError> {
        let deadline = Instant::now() + Duration::from_secs(30);
        let cfg = Config::new().with_manifest_url(manifest_url_override);

        let manifest = load_manifest(&cfg.updater_url, deadline)?;

        let mut results = Vec::new();

        // Determine whether @esm should be updated before esm (dep ordering).
        let esm_needs_mod_first = manifest
            .esm
            .as_ref()
            .and_then(|e| e.requires.get("@esm"))
            .map(|req| {
                let installed = version_file::read_installed_mod_version()
                    .unwrap_or(Version::new(0, 0, 0));
                !req.matches(&installed)
            })
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
        if (update_mod || (esm_needs_mod_first && update_ext))
            && manifest.at_esm.is_some()
        {
            if let Some(comp) = &manifest.at_esm {
                results.push(update_mod_bundle(comp, deadline)?);
            }
        }

        // esm extension.
        if update_ext {
            if let Some(comp) = &manifest.esm {
                results.push(update_esm_extension(comp, deadline)?);
            }
        }

        // Updater components.
        if update_updater {
            if let Some(comp) = &manifest.extension_updater {
                results.push(update_updater_extension(comp, deadline)?);
            }

            if let Some(comp) = &manifest.mod_updater {
                results.push(update_mod_updater_pbo(comp, deadline)?);
            }

            // Self-update the CLI binary.
            if let Ok(current_exe) = std::env::current_exe() {
                if let Some(dir) = current_exe.parent() {
                    // Only self-update if there's a manifest entry for the
                    // CLI updater (reusing extension_updater slot or
                    // a dedicated field — here we skip if none available).
                    // Self-update is a best-effort operation; log and continue.
                    let _ = dir; // suppress unused warning
                }
            }
        }

        Ok(results)
    }
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
    let production_pubkey = extract_raw_pubkey(UPDATER_PUBKEY)?;
    verify_with_key(&manifest_bytes, &sig_bytes, production_pubkey)?;
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

    download_to(&comp.url, &temp_file, deadline)?;
    let download_elapsed_ms = download_started_at.elapsed().as_millis();

    let checksum_started_at = Instant::now();
    if let Err(e) = verify_sha256(&temp_file, &comp.sha256) {
        let _ = std::fs::remove_file(&temp_file);
        return Err(e);
    }
    let checksum_elapsed_ms = checksum_started_at.elapsed().as_millis();

    let swap_started_at = Instant::now();
    let filename = esm_extension_filename();
    let dest = Path::new("@esm").join(filename);
    swap_file(&temp_file, &dest)?;
    let swap_elapsed_ms = swap_started_at.elapsed().as_millis();

    log::info!(
        "[check_update] download={download_elapsed_ms}ms \
         checksum={checksum_elapsed_ms}ms swap={swap_elapsed_ms}ms"
    );

    Ok(())
}

// ── CLI per-component update functions ───────────────────────────────────────

fn update_mod_bundle(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let temp_dir = Path::new("@esm/temp/addons_stage");
    let archive = Path::new("@esm/temp/at_esm_update.tar.gz");
    download_to(&comp.url, archive, deadline)?;
    verify_sha256(archive, &comp.sha256)?;
    extract_tar_gz(archive, temp_dir)?;

    let addons = Path::new("@esm/addons");
    let backup = Path::new("@esm/addons.backup");
    if addons.exists() {
        std::fs::rename(addons, backup)?;
    }
    std::fs::rename(temp_dir, addons)?;
    version_file::write_version(&comp.version)?;
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
    download_to(&comp.url, &temp_file, deadline)?;
    verify_sha256(&temp_file, &comp.sha256)?;

    let dest = Path::new("@esm").join(filename);
    swap_file(&temp_file, &dest)?;

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] esm | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "esm".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

fn update_updater_extension(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let dest = Path::new("@esm/esm_updater_ext");
    let temp = Path::new("@esm/temp/ext_updater");
    std::fs::create_dir_all(Path::new("@esm/temp"))?;
    download_to(&comp.url, temp, deadline)?;
    verify_sha256(temp, &comp.sha256)?;
    swap_file(temp, dest)?;

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] extension_updater | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "extension_updater".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

fn update_mod_updater_pbo(
    comp: &ComponentVersion,
    deadline: Instant,
) -> Result<UpdatedComponent, UpdaterError> {
    let started_at = Instant::now();
    let dest = Path::new("@esm/esm_mod_updater.pbo");
    let temp = Path::new("@esm/temp/mod_updater.pbo");
    std::fs::create_dir_all(Path::new("@esm/temp"))?;
    download_to(&comp.url, temp, deadline)?;
    verify_sha256(temp, &comp.sha256)?;
    swap_file(temp, dest)?;

    let elapsed_ms = started_at.elapsed().as_millis() as u64;
    log::info!("[update] mod_updater | total={elapsed_ms}ms");
    Ok(UpdatedComponent {
        name: "mod_updater".into(),
        version: comp.version.to_string(),
        elapsed_ms,
    })
}

// ── Utilities ─────────────────────────────────────────────────────────────────

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
