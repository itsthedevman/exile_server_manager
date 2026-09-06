use std::{fs, path::PathBuf};

use colored::Colorize;

use crate::{
    config::parse,
    context::{find_git_root, select_instances, Args, BuildOS, StageArgs},
    error::{BuildError, BuildResult},
    extra_mods,
    steps::mod_build::esm_crate_version,
    target::{build_target, Target},
};

/// The component names the updater reads out of `installed_versions.yml`, in the order they are written.
///
/// `@esm` is quoted because the updater's own record quotes it, and an unquoted `@` opens a YAML alias.
const COMPONENTS: [(&str, &str); 4] = [
    ("esm", "esm"),
    ("@esm", "\"@esm\""),
    ("extension_updater", "extension_updater"),
    ("mod_updater", "mod_updater"),
];

/// A version of `none` means "record nothing for this component", which the updater reads as 0.0.0.
const ABSENT: &str = "none";

/// Put one server's `@esm` into a known starting position, so an updater run has something to move away from.
///
/// Deliberately does not build, deploy, or start anything. `bin/build` already does each of those, and a second
/// path into any of them would drift from the one under test. What is here is the state an updater test needs and
/// nothing else.
///
/// Nor does it construct a [`crate::context::BuildContext`]. That would build a `FileWatcher`, and taking a
/// snapshot is a claim about what has been built: staging would mark every pending edit as seen and the next
/// build would find nothing to do, deploying the previous artifact while reporting success.
pub fn stage(args: &Args, stage_args: &StageArgs) -> BuildResult {
    if args.all_instances() {
        return Err(BuildError::Config(
            "Staging writes one server's install, so it cannot be combined with --all. Pass --server-id to \
             name the one being staged."
                .into(),
        ));
    }

    let git_path = find_git_root()?;
    let config = parse(&git_path.join("config.yml"))?;
    let instances = select_instances(args, &config)?;

    // `select_instances` errors on an unknown id and `parse` rejects an empty instance list, so there is always
    // exactly one here.
    let instance = &instances[0];
    let target = build_target(args, &config, &extra_mods::discover(&git_path), instance)?;

    // Rewriting @esm under a live server produces a half-swapped install, and a test result that describes
    // neither the before nor the after.
    if target.arma_running() {
        return Err(BuildError::General(format!(
            "The Arma server for '{}' is running. Stop it before staging: what this writes is the starting \
             position of a test, and a server reading those files while they change invalidates the run.",
            instance.server_id
        )));
    }

    let esm_dir = target.server_path().join("@esm");

    if stage_args.wipe {
        wipe_install(target.as_ref(), &esm_dir)?;
    }

    let versions = resolve_versions(stage_args, &git_path)?;
    write_version_record(target.as_ref(), &esm_dir, &versions)?;

    if stage_args.cli {
        install_cli(args, target.as_ref(), &git_path, &esm_dir)?;
    }

    report(instance.server_id.as_str(), &versions, stage_args);

    Ok(())
}

/// Strip `@esm` back to what a first-time install starts from.
///
/// `esm.key` and `config.yml` survive. The updater neither installs nor owns them, and without the key the server
/// comes back up unable to authenticate, which reads as a broken update rather than as a missing key.
///
/// Every extension filename is removed rather than only this target's, because the install being staged may have
/// been left by a run for the other one, and a stale `esm_x64.so` beside a fresh `esm_x64.dll` is a version record
/// that describes neither.
fn wipe_install(target: &dyn Target, esm_dir: &std::path::Path) -> BuildResult {
    let extensions = ["esm.so", "esm_x64.so", "esm.dll", "esm_x64.dll"]
        .iter()
        .map(|name| esm_dir.join(name))
        .collect::<Vec<_>>();

    let mut paths = vec![esm_dir.join("addons"), esm_dir.join("installed_versions.yml")];
    paths.extend(extensions);

    target.remove_paths(&paths.iter().map(PathBuf::as_path).collect::<Vec<_>>())
}

/// What each component's recorded version should become.
///
/// Anything not named keeps the version the current source would install, so one flag moves one thing and the
/// rest read as already up to date. After a wipe that default flips: an install that has never run the updater
/// has no record of anything.
fn resolve_versions(
    stage_args: &StageArgs,
    git_path: &std::path::Path,
) -> Result<Vec<(&'static str, String)>, BuildError> {
    // Only read when something actually falls back to it, so a wipe of every component does not fail on a
    // version it was never going to record.
    let default = if stage_args.wipe {
        ABSENT.to_string()
    } else {
        esm_crate_version(git_path)?
    };

    let named = [
        &stage_args.esm,
        &stage_args.server_mod,
        &stage_args.updater_ext,
        &stage_args.updater_mod,
    ];

    Ok(COMPONENTS
        .iter()
        .zip(named)
        .map(|((name, _), given)| {
            (*name, given.clone().unwrap_or_else(|| default.clone()))
        })
        .collect())
}

/// Write `installed_versions.yml`, or remove it when every component is absent.
///
/// An empty file is not the same as a missing one. The updater reads the first as a record of nothing and the
/// second as no record at all, and only one of those is a first-time install.
fn write_version_record(
    target: &dyn Target,
    esm_dir: &std::path::Path,
    versions: &[(&str, String)],
) -> BuildResult {
    let record = esm_dir.join("installed_versions.yml");

    let entries: Vec<String> = COMPONENTS
        .iter()
        .zip(versions)
        .filter(|(_, (_, version))| version != ABSENT)
        .map(|((_, key), (_, version))| format!("{key}: {version}"))
        .collect();

    if entries.is_empty() {
        return target.remove_paths(&[record.as_path()]);
    }

    let contents = format!(
        "# Written by `bin/stage`, not by the updater. This is a test starting position, not a record of what is\n\
         # actually on disk.\n\n{}\n",
        entries.join("\n")
    );

    target.write_file(&record, contents.as_bytes())
}

/// Put the updater CLI on the target, which a build never deploys.
fn install_cli(
    args: &Args,
    target: &dyn Target,
    git_path: &std::path::Path,
    esm_dir: &std::path::Path,
) -> BuildResult {
    let name = match args.build_os() {
        BuildOS::Linux => "esm_updater",
        BuildOS::Windows => "esm_updater.exe",
    };

    let packaged = git_path.join("target").join("build_release").join("@esm").join("bin").join(name);

    let contents = fs::read(&packaged).map_err(|e| {
        BuildError::General(format!(
            "{e} — no updater CLI at {}. A build does not produce one; run bin/package or \
             bin/updater_tester serve first.",
            packaged.display()
        ))
    })?;

    target.write_executable(&esm_dir.join("bin").join(name), &contents)
}

fn report(server_id: &str, versions: &[(&str, String)], stage_args: &StageArgs) {
    println!("\n{} staged", server_id.bold());

    for (name, version) in versions {
        println!("  {name:<18} {version}");
    }

    if stage_args.wipe {
        println!("  @esm stripped to a first-install state (esm.key and config.yml kept)");
    }

    if stage_args.cli {
        println!("  updater CLI installed in @esm/bin");
    }

    println!(
        "\nPoint a boot check at a local manifest with {}, then start it with {}.",
        "bin/build --updater-url <url>".bold(),
        "bin/dev --start-only".bold()
    );
}
