use std::fs;

use crate::{context::BuildContext, error::BuildResult};

/// Prepare the local `target/@esm/` staging directory.
///
/// Wipes only the portions being rebuilt so that partial rebuilds leave
/// everything else intact. Ensures required subdirectories exist.
pub fn prepare_staging(ctx: &mut BuildContext) -> BuildResult {
    let staging = ctx.local_build_path.join("@esm");

    if ctx.rebuild_mod() {
        for dir in &["addons", "sql", "optionals"] {
            let p = staging.join(dir);
            if p.exists() {
                fs::remove_dir_all(&p)?;
            }
        }
        for file in &["README.md", "version"] {
            let p = staging.join(file);
            if p.exists() {
                fs::remove_file(&p)?;
            }
        }
    }

    if ctx.rebuild_extension() {
        for pattern in &["esm*.so", "esm*.dll"] {
            for entry in glob::glob(&staging.join(pattern).to_string_lossy())
                .into_iter()
                .flatten()
                .flatten()
            {
                fs::remove_file(entry)?;
            }
        }
    }

    // Ensure required directories exist
    fs::create_dir_all(staging.join("addons"))?;
    fs::create_dir_all(staging.join("log"))?;

    // Clean up stale build artefacts
    for name in &[
        "@esm.zip",
        "windows.zip",
        "linux.zip",
        "esm.zip",
        ".esm-build-command",
        ".esm-build-command-result",
    ] {
        let p = ctx.local_build_path.join(name);
        if p.is_file() {
            fs::remove_file(p)?;
        }
    }

    Ok(())
}
