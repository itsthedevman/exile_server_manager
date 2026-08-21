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
    log::info!("[load_manifest] fetching {url}");

    let (manifest_bytes, sig_bytes) = fetch_manifest(url, deadline)?;
    log::info!(
        "[load_manifest] fetched {} bytes, signature {} bytes",
        manifest_bytes.len(),
        sig_bytes.len()
    );

    verify_with_key(&manifest_bytes, &sig_bytes, &verification_key()?)?;
    log::info!("[load_manifest] signature verified");

    serde_json::from_slice(&manifest_bytes)
        .map_err(|e| UpdaterError::Parse(e.to_string()))
}

/// Atomically swap `source` into `dest` using a `.backup` intermediate.
///
/// On success the backup is removed. On failure the backup is restored.
///
/// The replacement inherits the permissions of the file it replaces. A downloaded file carries whatever the
/// download gave it, so without this an updated install ends up subtly different from a packaged one for no reason
/// anybody chose.
/// Whether an IO error is Windows refusing to touch a file another process holds open.
///
/// `ERROR_SHARING_VIOLATION` (32) and `ERROR_LOCK_VIOLATION` (33) are the two ways it surfaces. Linux has no
/// equivalent: it will happily rename a file out from under a running process, which is why this whole class of
/// failure is invisible until the code runs on Windows.
#[cfg(windows)]
fn is_file_in_use(error: &std::io::Error) -> bool {
    matches!(error.raw_os_error(), Some(32) | Some(33))
}

#[cfg(not(windows))]
fn is_file_in_use(_error: &std::io::Error) -> bool {
    false
}

/// Turn an IO error into [`UpdaterError::FileInUse`] when that is what it is, and a plain IO error otherwise.
fn describe_io(error: std::io::Error, path: &Path) -> UpdaterError {
    if is_file_in_use(&error) {
        return UpdaterError::FileInUse {
            path: path.display().to_string(),
        };
    }

    UpdaterError::Io(error)
}

/// Replace the directory `dest` with `stage`, putting `dest` back if the move fails.
///
/// The two renames differ in what a failure costs. The first is safe: nothing has moved yet, so returning an
/// error leaves the install exactly as it was. The second is not, because `dest` has already been moved aside;
/// returning without restoring it leaves the server with no addons directory at all rather than an out-of-date
/// one, its contents stranded under a backup name nothing looks for.
///
/// Removing `backup` on success is the caller's, since only it knows whether the version record was written.
fn replace_directory(stage: &Path, dest: &Path, backup: &Path) -> Result<(), UpdaterError> {
    if dest.exists() {
        std::fs::rename(dest, backup).map_err(|e| describe_io(e, dest))?;
    }

    if let Err(e) = std::fs::rename(stage, dest) {
        if backup.exists() {
            let _ = std::fs::rename(backup, dest);
        }

        return Err(describe_io(e, dest));
    }

    Ok(())
}

fn swap_file(source: &Path, dest: &Path) -> Result<(), UpdaterError> {
    let backup = dest.with_file_name(format!(
        "{}.backup",
        dest.file_name()
            .unwrap_or_default()
            .to_string_lossy()
    ));

    // Read before the rename below moves the file out from under it.
    #[cfg(unix)]
    let existing_mode = {
        use std::os::unix::fs::PermissionsExt;
        std::fs::metadata(dest)
            .ok()
            .map(|meta| meta.permissions().mode())
    };

    if dest.exists() {
        std::fs::rename(dest, &backup).map_err(|e| describe_io(e, dest))?;
    }
    match std::fs::rename(source, dest) {
        Ok(()) => {
            #[cfg(unix)]
            if let Some(mode) = existing_mode {
                use std::os::unix::fs::PermissionsExt;
                let _ = std::fs::set_permissions(dest, std::fs::Permissions::from_mode(mode));
            }

            let _ = std::fs::remove_file(&backup);
            Ok(())
        }
        Err(e) => {
            if backup.exists() {
                let _ = std::fs::rename(&backup, dest);
            }
            Err(describe_io(e, dest))
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

/// Download one artifact, verify it, and swap it into place, saying so at each step.
///
/// The three file-swap components differ only in where the bytes come from and where they land. Narrating it once
/// here means a run that failed halfway says which of download, checksum, or swap it died on, and a run that
/// succeeded says what it actually wrote, which is the question a support request usually turns on.
fn install_artifact(
    component: &str,
    comp: &ComponentVersion,
    temp: &Path,
    dest: &Path,
    deadline: Instant,
) -> Result<(), UpdaterError> {
    let artifact = artifact_for(comp)?;

    log::info!("[update] {component}: downloading {}", artifact.url);

    let download_started_at = Instant::now();
    download_to(&artifact.url, temp, deadline)?;

    let size = std::fs::metadata(temp).map(|meta| meta.len()).unwrap_or(0);
    log::info!(
        "[update] {component}: downloaded {size} bytes in {}ms",
        download_started_at.elapsed().as_millis()
    );

    verify_sha256(temp, &artifact.sha256).inspect_err(|_| {
        let _ = std::fs::remove_file(temp);
    })?;
    log::info!("[update] {component}: checksum verified");

    // The staged copy is removed whichever way the swap goes. Left behind it is a whole extension of dead
    // weight per failed attempt, and the most likely reason to fail here is a running server, which is also the
    // most likely thing to be retried a few times before anybody stops it.
    swap_file(temp, dest).inspect_err(|_| {
        let _ = std::fs::remove_file(temp);
    })?;
    log::info!("[update] {component}: installed to {}", dest.display());

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
    let artifact = artifact_for(comp)?;

    log::info!("[update] @esm: downloading {}", artifact.url);

    let download_started_at = Instant::now();
    download_to(&artifact.url, archive, deadline)?;

    let size = std::fs::metadata(archive).map(|meta| meta.len()).unwrap_or(0);
    log::info!(
        "[update] @esm: downloaded {size} bytes in {}ms",
        download_started_at.elapsed().as_millis()
    );

    verify_sha256(archive, &artifact.sha256).inspect_err(|_| {
        let _ = std::fs::remove_file(archive);
    })?;
    log::info!("[update] @esm: checksum verified");

    extract_tar_gz(archive, temp_dir).inspect_err(|_| {
        let _ = std::fs::remove_dir_all(temp_dir);
        let _ = std::fs::remove_file(archive);
    })?;
    log::info!("[update] @esm: extracted to {}", temp_dir.display());

    let addons = Path::new("@esm/addons");
    let backup = Path::new("@esm/addons.backup");

    replace_directory(temp_dir, addons, backup).inspect_err(|_| {
        let _ = std::fs::remove_dir_all(temp_dir);
        let _ = std::fs::remove_file(archive);
    })?;

    log::info!("[update] @esm: installed to {}", addons.display());

    record_installed(Component::EsmMod, &comp.version);
    if backup.exists() {
        let _ = std::fs::remove_dir_all(backup);
    }

    let _ = std::fs::remove_file(archive);

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
    let temp_dir = Path::new("@esm/temp");
    std::fs::create_dir_all(temp_dir)?;

    let temp_file = temp_dir.join("esm_update");
    let dest = Path::new("@esm").join(esm_extension_filename());

    install_artifact("esm", comp, &temp_file, &dest, deadline)?;
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

    install_artifact("extension_updater", comp, temp, &dest, deadline)?;
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
    let dest = Path::new("@esm/addons/exile_server_manager_updater.pbo");
    let temp = Path::new("@esm/temp/mod_updater.pbo");
    std::fs::create_dir_all(Path::new("@esm/temp"))?;
    std::fs::create_dir_all(Path::new("@esm/addons"))?;

    install_artifact("mod_updater", comp, temp, dest, deadline)?;
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

#[cfg(test)]
mod swap_tests {
    use super::{replace_directory, swap_file};
    use std::fs;

    /// The rollback the Windows test bed could not trigger by racing: extraction and rename together take about
    /// 11ms, so nothing external gets between them reliably. Making the second rename fail on purpose is the
    /// only way to actually execute the path, rather than read it and assume.
    #[test]
    fn replace_directory_puts_the_original_back_when_the_move_fails() {
        let root = tempfile::tempdir().unwrap();
        let dest = root.path().join("addons");
        let backup = root.path().join("addons.backup");
        let stage = root.path().join("addons_stage");

        fs::create_dir(&dest).unwrap();
        fs::write(dest.join("exile_server_manager.pbo"), b"the installed mod").unwrap();

        // `stage` deliberately does not exist, so the second rename fails after the first has already moved
        // `dest` aside. That is the state the missing rollback used to leave behind.
        let result = replace_directory(&stage, &dest, &backup);
        assert!(result.is_err(), "a missing stage directory must not report success");

        assert!(dest.is_dir(), "addons was left missing, which is worse than being out of date");
        assert_eq!(
            fs::read(dest.join("exile_server_manager.pbo")).unwrap(),
            b"the installed mod",
            "addons came back without its contents"
        );
        assert!(!backup.exists(), "the backup name was left behind for nothing to find");
    }

    #[test]
    fn replace_directory_installs_the_staged_copy() {
        let root = tempfile::tempdir().unwrap();
        let dest = root.path().join("addons");
        let backup = root.path().join("addons.backup");
        let stage = root.path().join("addons_stage");

        fs::create_dir(&dest).unwrap();
        fs::write(dest.join("old.pbo"), b"old").unwrap();
        fs::create_dir(&stage).unwrap();
        fs::write(stage.join("new.pbo"), b"new").unwrap();

        replace_directory(&stage, &dest, &backup).unwrap();

        assert!(dest.join("new.pbo").exists());
        assert!(!dest.join("old.pbo").exists());
        assert!(!stage.exists(), "the staging directory should have been moved, not copied");
    }

    #[test]
    fn replace_directory_works_on_a_first_install_with_nothing_to_replace() {
        let root = tempfile::tempdir().unwrap();
        let dest = root.path().join("addons");
        let backup = root.path().join("addons.backup");
        let stage = root.path().join("addons_stage");

        fs::create_dir(&stage).unwrap();
        fs::write(stage.join("new.pbo"), b"new").unwrap();

        replace_directory(&stage, &dest, &backup).unwrap();

        assert!(dest.join("new.pbo").exists());
        assert!(!backup.exists());
    }

    #[test]
    fn swap_file_puts_the_original_back_when_the_move_fails() {
        let root = tempfile::tempdir().unwrap();
        let dest = root.path().join("esm_x64.dll");
        let source = root.path().join("esm_update");

        fs::write(&dest, b"the installed extension").unwrap();

        // Same shape as above: no source, so the swap fails once the original has been moved aside.
        assert!(swap_file(&source, &dest).is_err());

        assert_eq!(
            fs::read(&dest).unwrap(),
            b"the installed extension",
            "the extension was not restored after a failed swap"
        );
        assert!(
            !dest.with_file_name("esm_x64.dll.backup").exists(),
            "a .backup file was left next to the extension"
        );
    }
}
