use crate::{
    context::{BuildArch, BuildContext, BuildOS, has_directory_changed},
    error::BuildResult,
    ADDONS,
};

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
