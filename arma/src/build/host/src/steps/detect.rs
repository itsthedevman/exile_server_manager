use std::fs;

use crate::{
    context::{BuildArch, BuildContext, BuildOS, has_directory_changed},
    error::BuildResult,
    ADDONS,
};

/// Records which build configuration produced the current staging tree.
///
/// Kept beside the watcher cache rather than inside `target/@esm/`, because everything in there is uploaded to a
/// server and packed into a release zip. A build marker is neither of those things.
const BUILD_PROFILE_FILE: &str = ".esm-build-profile";

/// Decide what needs rebuilding based on expected local artifacts.
///
/// Checks `target/@esm/` for the expected PBOs and extension `.so` files.
/// If any are missing, triggers a full rebuild. Also triggers a mod rebuild
/// if the SQF compiler source has changed.
pub fn detect_rebuild(ctx: &mut BuildContext) -> BuildResult {
    if ctx.args.full_rebuild() {
        // Already set in BuildContext::new — nothing to do
        return Ok(());
    }

    // Before any of the artifact checks below, because those ask whether a file is present and this asks whether
    // the present one is the right kind. An artifact built under another configuration is the wrong one no matter
    // how recently it was built.
    if staged_profile(ctx).as_deref() != Some(build_profile(ctx).as_str()) {
        ctx.rebuild_mod = true;
        ctx.rebuild_extension = true;
        return Ok(());
    }

    let staging = ctx.local_build_path.join("@esm");

    // Check PBOs
    let missing_pbo = ADDONS.iter().any(|addon| {
        !staging.join("addons").join(format!("{addon}.pbo")).exists()
    });

    if missing_pbo {
        ctx.rebuild_mod = true;
        ctx.rebuild_extension = true;
        return Ok(());
    }

    // Check extension artifact
    let ext_name = extension_filename(ctx.args.build_arch(), ctx.args.build_os());
    if !staging.join(&ext_name).exists() {
        ctx.rebuild_extension = true;
    }

    // Compiler source change triggers mod rebuild
    let compiler_changed = has_directory_changed(
        &ctx.file_watcher,
        &ctx.git_path.join("src").join("build").join("compiler"),
    );
    if compiler_changed {
        ctx.rebuild_mod = true;
    }

    Ok(())
}

/// Note that this run's build phase finished, so the next one can trust what it finds in the staging tree.
///
/// Both halves say the same thing about different questions. The watcher answers "have the sources changed since
/// the artifact was built", and the profile answers "was it built the way this run is asking for". Neither is
/// written until a build has actually happened: a run that only starts a server or stages a test position leaves
/// both alone, so it cannot convince the next build that its work is already done.
pub fn record_build(ctx: &BuildContext) -> BuildResult {
    ctx.file_watcher.record().map_err(crate::error::BuildError::General)?;

    fs::write(
        ctx.local_build_path.join(BUILD_PROFILE_FILE),
        build_profile(ctx),
    )?;

    Ok(())
}

/// The configuration this run is asking for, as it gets stamped onto the staging tree.
///
/// `--release` earns a place here alongside the target because it changes what lands in the tree, not just how it
/// was compiled: the extension is built without the `development` feature, and the mod drops its test addon. An
/// artifact from the other profile is the wrong artifact, and it is the same filename either way, so the name
/// cannot be what tells them apart.
fn build_profile(ctx: &BuildContext) -> String {
    profile_name(ctx.args.build_os(), ctx.args.build_arch(), ctx.args.release)
}

fn profile_name(os: BuildOS, arch: BuildArch, release: bool) -> String {
    let arch = match arch {
        BuildArch::X32 => "x32",
        BuildArch::X64 => "x64",
    };

    let profile = if release { "release" } else { "development" };

    format!("{os}-{arch}-{profile}")
}

/// What produced the tree that is there now, or `None` when nothing has recorded one.
///
/// An absent stamp reads as a mismatch rather than as agreement, which is what makes the first build after this
/// lands do the full rebuild it needs instead of trusting a tree of unknown origin.
fn staged_profile(ctx: &BuildContext) -> Option<String> {
    fs::read_to_string(ctx.local_build_path.join(BUILD_PROFILE_FILE)).ok()
}

pub fn extension_filename(arch: BuildArch, os: BuildOS) -> String {
    let suffix = match arch {
        BuildArch::X32 => "",
        BuildArch::X64 => "_x64",
    };
    let ext = match os {
        BuildOS::Linux => "so",
        BuildOS::Windows => "dll",
    };
    format!("esm{suffix}.{ext}")
}

pub fn updater_filename(arch: BuildArch, os: BuildOS) -> String {
    let suffix = match arch {
        BuildArch::X32 => "",
        BuildArch::X64 => "_x64",
    };
    let ext = match os {
        BuildOS::Linux => "so",
        BuildOS::Windows => "dll",
    };
    format!("esm_updater{suffix}.{ext}")
}

#[cfg(test)]
mod tests {
    use super::profile_name;
    use crate::context::{BuildArch, BuildOS};

    /// The bug this exists to stop. `bin/staging` builds `--release` and `bin/dev` does not, both write
    /// `esm_x64.so`, and the old detection only asked whether that file was present. So a dev run after a staging
    /// run found the release extension sitting there, decided there was nothing to do, and deployed a build with
    /// no `development` feature. The mod half is worse in the other direction: a release packed after a dev build
    /// kept the test addon, which is not in ADDONS and so was never noticed missing.
    #[test]
    fn release_and_development_are_different_profiles_despite_the_shared_filename() {
        assert_ne!(
            profile_name(BuildOS::Linux, BuildArch::X64, false),
            profile_name(BuildOS::Linux, BuildArch::X64, true)
        );
    }

    #[test]
    fn target_and_architecture_each_stand_on_their_own() {
        let baseline = profile_name(BuildOS::Linux, BuildArch::X64, false);

        assert_ne!(baseline, profile_name(BuildOS::Windows, BuildArch::X64, false));
        assert_ne!(baseline, profile_name(BuildOS::Linux, BuildArch::X32, false));
    }
}
