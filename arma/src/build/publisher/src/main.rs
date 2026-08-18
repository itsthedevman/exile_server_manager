//! `publisher` — builds and signs the update manifest from a packaged release.
//!
//! This is the other half of the auto-updater: `updater_lib` consumes a signed `versions.json`, and this produces
//! one. It runs on a workstation, never on a server, and the signing key never leaves the machine it runs on.
//!
//! It is deliberately separate from cutting a release. Decoupling them means a version can be retargeted or rolled back
//! by publishing a new manifest, without cutting a release to do it.
//!
//! The manifest is built out of `updater_lib`'s own types rather than assembled as raw JSON, so the document this
//! writes and the document the updater parses cannot drift apart. A field added on one side fails to compile on the
//! other.

use clap::Parser;
use std::collections::BTreeMap;
use std::path::{Path, PathBuf};
use updater_lib::manifest::{Artifact, ComponentVersion, VersionManifest};

/// Build a signed update manifest from a packaged release directory.
#[derive(Parser)]
#[command(name = "publisher")]
struct Cli {
    /// Directory `bin/package` wrote its output to.
    #[arg(long, default_value = "target/build_release")]
    release_dir: PathBuf,

    /// Version of the extension and the mod bundle, e.g. `2.1.0`.
    ///
    /// Those two ship as a matched pair and the mod carries no version of its own, so one number covers both.
    #[arg(long)]
    version: semver::Version,

    /// Version of the updater's own extension and addon, e.g. `0.1.0`.
    ///
    /// Separate from `--version` because the updater changes on its own schedule. Sharing one number would mean
    /// either offering an unchanged component to every server because the extension moved, or never offering a
    /// changed one because it did not.
    #[arg(long)]
    updater_version: semver::Version,

    /// Version of the operator CLI, e.g. `0.1.0`.
    ///
    /// Separate again, and load-bearing: the CLI compares this against the version it was built with in order to
    /// tell an operator they are driving a stale tool. A number it cannot match is a warning nobody can act on.
    #[arg(long)]
    cli_version: semver::Version,

    /// URL prefix every artifact is served from. Each file is appended to this by name.
    #[arg(long)]
    base_url: String,

    /// Where to write the manifest.
    #[arg(long, default_value = "target/build_release/versions.json")]
    out: PathBuf,

    /// Private key to sign with. Without it the manifest is written unsigned and must be signed separately.
    #[arg(long)]
    key: Option<PathBuf>,

    /// Minimum `@esm` version the extension release requires, e.g. `>=2.1.0`.
    #[arg(long)]
    esm_requires_mod: Option<semver::VersionReq>,
}

/// One publishable file: where it sits in the release directory, and the platform it serves.
struct Mapping {
    platform: &'static str,
    relative_path: &'static str,
}

/// The extension, one native binary per Arma server build.
const ESM: &[Mapping] = &[
    Mapping { platform: "linux-x64", relative_path: "@esm/esm_x64.so" },
    Mapping { platform: "linux-x86", relative_path: "@esm/esm.so" },
    Mapping { platform: "windows-x64", relative_path: "@esm/esm_x64.dll" },
    Mapping { platform: "windows-x86", relative_path: "@esm/esm.dll" },
];

/// The updater's own extension, same four builds.
const EXTENSION_UPDATER: &[Mapping] = &[
    Mapping { platform: "linux-x64", relative_path: "@esm/esm_updater_x64.so" },
    Mapping { platform: "linux-x86", relative_path: "@esm/esm_updater.so" },
    Mapping { platform: "windows-x64", relative_path: "@esm/esm_updater_x64.dll" },
    Mapping { platform: "windows-x86", relative_path: "@esm/esm_updater.dll" },
];

/// The operator CLI. Only built for 64-bit; a 32-bit server can still run the 64-bit tool.
const UPDATER_CLI: &[Mapping] = &[
    Mapping { platform: "linux-x64", relative_path: "@esm/bin/esm_updater" },
    Mapping { platform: "windows-x64", relative_path: "@esm/bin/esm_updater.exe" },
];

/// The mod bundle, one archive for every server.
const ESM_MOD: &[Mapping] = &[Mapping { platform: "any", relative_path: "@esm-addons.tar.gz" }];

/// The mod-side updater PBO, likewise platform-neutral.
const MOD_UPDATER: &[Mapping] =
    &[Mapping { platform: "any", relative_path: "@esm/addons/esm_updater.pbo" }];

fn main() {
    if let Err(e) = run() {
        eprintln!("publisher: {e}");
        std::process::exit(1);
    }
}

fn run() -> Result<(), String> {
    let cli = Cli::parse();

    let mut esm = component(&cli, ESM, &cli.version)?;
    if let Some(requirement) = &cli.esm_requires_mod {
        esm.requires.insert("@esm".to_string(), requirement.clone());
    }

    // The updater's extension and addon share a number because they are a matched pair: the addon calls into the
    // extension, so shipping one without the other is never what anyone wants.
    let manifest = VersionManifest {
        esm: Some(esm),
        esm_mod: Some(component(&cli, ESM_MOD, &cli.version)?),
        extension_updater: Some(component(&cli, EXTENSION_UPDATER, &cli.updater_version)?),
        mod_updater: Some(component(&cli, MOD_UPDATER, &cli.updater_version)?),
        updater_cli: Some(component(&cli, UPDATER_CLI, &cli.cli_version)?),
    };

    let json = serde_json::to_vec_pretty(&manifest)
        .map_err(|e| format!("could not serialize the manifest: {e}"))?;

    if let Some(parent) = cli.out.parent() {
        std::fs::create_dir_all(parent)
            .map_err(|e| format!("could not create {}: {e}", parent.display()))?;
    }
    std::fs::write(&cli.out, &json)
        .map_err(|e| format!("could not write {}: {e}", cli.out.display()))?;

    println!("wrote {}", cli.out.display());

    match &cli.key {
        Some(key) => sign(&cli.out, key)?,
        None => println!(
            "NOT SIGNED. An unsigned manifest is rejected by every server; sign it before publishing."
        ),
    }

    Ok(())
}

/// Build one component entry, hashing each file that exists.
///
/// A missing file is skipped rather than fatal, because not every release ships every platform, and a package built
/// with `--skip-updater` legitimately has no updater artifacts at all. A component with no files at all is the
/// caller's problem to notice, so it is reported.
///
/// `version` is passed rather than read from `cli` because components version independently; see the flags on
/// `Cli` for which number belongs to which.
fn component(
    cli: &Cli,
    mappings: &[Mapping],
    version: &semver::Version,
) -> Result<ComponentVersion, String> {
    let mut artifacts = BTreeMap::new();

    for mapping in mappings {
        let path = cli.release_dir.join(mapping.relative_path);
        if !path.exists() {
            println!("skipping {} (not in this package)", mapping.relative_path);
            continue;
        }

        let name = path
            .file_name()
            .ok_or_else(|| format!("{} has no filename", path.display()))?
            .to_string_lossy()
            .into_owned();

        artifacts.insert(
            mapping.platform.to_string(),
            Artifact {
                url: format!("{}/{name}", cli.base_url.trim_end_matches('/')),
                sha256: sha256_of(&path)?,
            },
        );
    }

    if artifacts.is_empty() {
        return Err(format!(
            "no artifacts found under {} for this component",
            cli.release_dir.display()
        ));
    }

    Ok(ComponentVersion {
        version: version.clone(),
        artifacts,
        release_date: None,
        changes: None,
        requires: BTreeMap::new(),
    })
}

fn sha256_of(path: &Path) -> Result<String, String> {
    use sha2::{Digest, Sha256};

    let bytes = std::fs::read(path).map_err(|e| format!("could not read {}: {e}", path.display()))?;
    let mut hasher = Sha256::new();
    hasher.update(&bytes);

    Ok(hex::encode(hasher.finalize()))
}

/// Sign the manifest with openssl, producing the detached `.sig` the updater expects.
///
/// Shelling out rather than signing in-process keeps the private key in a PEM file openssl already knows how to
/// read, and keeps this tool from ever holding key material in its own memory. ed25519 signs the message directly,
/// hence `-rawin`.
fn sign(manifest: &Path, key: &Path) -> Result<(), String> {
    let signature = manifest.with_extension("json.sig");

    let status = std::process::Command::new("openssl")
        .arg("pkeyutl")
        .arg("-sign")
        .arg("-rawin")
        .arg("-inkey")
        .arg(key)
        .arg("-in")
        .arg(manifest)
        .arg("-out")
        .arg(&signature)
        .status()
        .map_err(|e| format!("could not run openssl: {e}"))?;

    if !status.success() {
        return Err(format!("openssl failed to sign {}", manifest.display()));
    }

    println!("wrote {}", signature.display());
    Ok(())
}
