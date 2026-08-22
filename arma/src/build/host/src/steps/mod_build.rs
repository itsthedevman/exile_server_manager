use std::{
    fs,
    io::Cursor,
    path::{Path, PathBuf},
};

use compiler::Compiler;
use glob::glob;
use hemtt_pbo::WritablePbo;

use crate::{
    compile::bind_replacements,
    context::BuildContext,
    error::{BuildError, BuildResult},
    spinner::{MultiSpinner, SubLines},
    string_table, ADDONS,
};

pub fn build_mod(ctx: &mut BuildContext) -> BuildResult {
    let source_path = ctx.git_path.join("src").join("@esm");
    let build_path = ctx.local_build_path.join("@esm");
    // Addons are compiled here first, then packed into build_path as PBOs.
    // Keeping the unpacked sources out of build_path means the deployed
    // @esm/addons/ holds only .pbo files, never the raw source dirs.
    let work_path = ctx.local_build_path.join("mod_work");

    let has_test = !ctx.args.release;
    let addon_count = ADDONS.len() + if has_test { 1 } else { 0 };

    let mut sp = MultiSpinner::start("Building mod");
    let sub_lines = sp.sub_lines();

    // Sub-steps: compile, stringtable, sqf check, pack
    compile_sqf(ctx, &source_path, &work_path, &build_path).map_err(|e| {
        sp.sub_fail("Replacing macros", false);
        e
    })?;
    sp.sub_done("Replacing macros", false);

    string_table::convert_yaml_to_xml(
        work_path
            .join("addons")
            .join("exile_server_manager")
            .join("stringtable.yml"),
    )
    .map_err(|e| BuildError::General(e))?;

    // Write stringtable.xml was done by convert_yaml_to_xml internally
    sp.sub_done("Building stringtable.xml", false);

    check_sqf(
        &[work_path.join("addons"), build_path.join("optionals")],
        ctx,
    )
    .map_err(|e| {
        sp.sub_fail("Checking SQF", false);
        e
    })?;
    sp.sub_done("Checking SQF", false);

    pack_addons(&work_path, &build_path, has_test, &sub_lines).map_err(|e| {
        sp.sub_fail("Packing addons", false);
        e
    })?;
    sp.sub_done(&format!("Packing {} addons", addon_count), false);

    publish_compiled_sqf(ctx, &work_path).map_err(|e| {
        sp.sub_fail("Copying compiled SQF", false);
        e
    })?;
    sp.sub_done("Copying compiled SQF", false);

    copy_extras(ctx, &source_path, &build_path).map_err(|e| {
        sp.sub_fail("Copying extras", true);
        e
    })?;
    sp.sub_done("Copying extras", true);

    sp.done();
    Ok(())
}

fn compile_sqf(
    ctx: &BuildContext,
    source_path: &Path,
    work_path: &Path,
    build_path: &Path,
) -> BuildResult {
    let target_str = ctx.args.build_os().to_string();

    // Addons compile to the intermediate work dir (they get packed into PBOs
    // afterwards). Optionals ship unpacked, so they go straight into build_path.
    for (src, dst) in [
        (source_path.join("addons"), work_path.join("addons")),
        (source_path.join("optionals"), build_path.join("optionals")),
    ] {
        let mut compiler = Compiler::new();
        compiler
            .source(&src.to_string_lossy())
            .destination(&dst.to_string_lossy())
            .target(&target_str);

        bind_replacements(&mut compiler, &ctx.git_path);
        compiler.compile()?;
    }

    Ok(())
}

fn check_sqf(roots: &[PathBuf], ctx: &BuildContext) -> BuildResult {
    let sqfvm = ctx.git_path.join("bin").join("sqfvm");

    for root in roots {
        let pattern = format!("{}/**/*.sqf", root.display());

        let paths: Vec<_> = glob(&pattern)
            .map_err(|e| BuildError::General(e.to_string()))?
            .flatten()
            .collect();

        for sqf_path in paths {
            let output = std::process::Command::new(&sqfvm)
                .args([
                    "--automated",
                    "--parse-only",
                    "--no-spawn-player",
                    "--input-sqf",
                    &sqf_path.to_string_lossy(),
                ])
                .output()
                .map_err(|e| BuildError::General(e.to_string()))?;

            let combined = String::from_utf8_lossy(&output.stdout).to_string()
                + &String::from_utf8_lossy(&output.stderr);

            if combined.contains("Parse Error:") {
                return Err(BuildError::General(format!(
                    "SQF parse error in {}\n{}",
                    sqf_path.display(),
                    combined.trim()
                )));
            }
        }
    }

    Ok(())
}

fn pack_addons(
    work_path: &Path,
    build_path: &Path,
    include_test: bool,
    sub_lines: &SubLines,
) -> BuildResult {
    let src_addons = work_path.join("addons");
    let dst_addons = build_path.join("addons");
    fs::create_dir_all(&dst_addons)?;

    let mut addons: Vec<&str> = ADDONS.to_vec();
    if include_test {
        addons.push("esm_test");
    }

    // build_mod recompiles every addon as a unit, so we pack every addon as a
    // unit too. Keeping pack in lockstep with compile is what guarantees the
    // deployed @esm always has a complete set of PBOs.
    for addon in &addons {
        let src = src_addons.join(addon);
        let dst = dst_addons.join(format!("{addon}.pbo"));

        let file_count = pack_pbo(&src, &dst)?;
        sub_lines.print(&format!("{addon}.pbo ({file_count} files)"));
    }

    Ok(())
}

/// Moves the macro-expanded addon sources out of the throwaway `mod_work` dir into `target/sqf/` so the
/// compiled SQF survives the build and can be read back to confirm it is valid. Packing already pulled
/// everything it needs from `work_path`, so a move (rather than a copy) leaves nothing behind in the
/// intermediate dir. `prepare_staging` wiped any prior `target/sqf` on this rebuild, so the destination does
/// not exist yet and the rename lands the addon tree whole.
fn publish_compiled_sqf(ctx: &BuildContext, work_path: &Path) -> BuildResult {
    let src_addons = work_path.join("addons");
    let sqf_path = ctx.local_build_path.join("sqf");

    fs::rename(&src_addons, &sqf_path)?;

    Ok(())
}

/// Packs one addon directory into a PBO with HEMTT's `WritablePbo`.
///
/// Mirrors what `armake2 pack` did for these addons: every file under `src` is
/// added (including the `$PBOPREFIX$.txt` marker itself), and the prefix that
/// marker declares is written into the PBO header so Arma can resolve the
/// addon's virtual path. Unlike armake2, `WritablePbo` does not read the prefix
/// marker on its own, so we set it explicitly via `read_pbo_prefix`.
fn pack_pbo(src: &Path, dst: &Path) -> Result<usize, BuildError> {
    let mut pbo: WritablePbo<Cursor<Vec<u8>>> = WritablePbo::new();

    // Collect files in a stable order so rebuilds produce identical PBOs.
    let pattern = format!("{}/**/*", src.display());
    let mut files: Vec<PathBuf> = glob(&pattern)
        .map_err(|e| BuildError::General(e.to_string()))?
        .flatten()
        .filter(|p| p.is_file())
        .collect();
    files.sort();

    for path in &files {
        let rel = path
            .strip_prefix(src)
            .map_err(|e| BuildError::General(e.to_string()))?;
        // add_file normalizes forward slashes to backslashes internally.
        let name = rel.to_string_lossy().into_owned();
        let bytes = fs::read(path)?;
        pbo.add_file(name, Cursor::new(bytes))
            .map_err(|e| BuildError::General(e.to_string()))?;
    }

    if let Some(prefix) = read_pbo_prefix(src) {
        pbo.add_property("prefix", prefix);
    }

    let mut out = fs::File::create(dst)?;
    pbo.write(&mut out, true)
        .map_err(|e| BuildError::General(e.to_string()))?;

    Ok(files.len())
}

/// Reads the addon prefix from the Mikero-style marker file, trying the
/// historical names in turn. Returns the first non-empty line with an optional
/// `prefix=` lead-in stripped.
fn read_pbo_prefix(src: &Path) -> Option<String> {
    for marker in ["$PBOPREFIX$.txt", "$PBOPREFIX$", "$PREFIX$"] {
        let Ok(contents) = fs::read_to_string(src.join(marker)) else {
            continue;
        };

        let line = contents.lines().next().unwrap_or("").trim();
        let value = line
            .strip_prefix("prefix=")
            .or_else(|| line.strip_prefix("PREFIX="))
            .unwrap_or(line);

        if !value.is_empty() {
            return Some(value.to_string());
        }
    }

    None
}

fn copy_extras(
    _ctx: &BuildContext,
    source_path: &Path,
    build_path: &Path,
) -> BuildResult {
    // README.md
    let readme_src = source_path.join("README.md");
    if readme_src.exists() {
        fs::copy(&readme_src, build_path.join("README.md"))?;
    }

    // sql/ directory
    let sql_src = source_path.join("sql");
    if sql_src.exists() {
        let sql_dst = build_path.join("sql");
        if sql_dst.exists() {
            fs::remove_dir_all(&sql_dst)?;
        }
        copy_dir(&sql_src, &sql_dst)?;
    }

    // Seeding the updater's installed-version record, parked until the updater is tested and shipped. The updater is
    // its only consumer and we build with --skip-updater for now, so writing it just ships a file nothing reads.
    // Re-enable with the updater: uncomment, rename _ctx -> ctx in the signature above, and drop the
    // allow(dead_code) on esm_crate_version. Note the updater owns the whole file, so a build that writes it must
    // write the `@esm` key rather than the bare version this used to emit.
    // let version = esm_crate_version(&ctx.git_path);
    // fs::write(build_path.join("installed_versions.yml"), format!("\"@esm\": {version}\n"))?;

    Ok(())
}

fn copy_dir(src: &Path, dst: &Path) -> BuildResult {
    fs::create_dir_all(dst)?;
    for entry in fs::read_dir(src)? {
        let entry = entry?;
        let src_path = entry.path();
        let dst_path = dst.join(entry.file_name());
        if src_path.is_dir() {
            copy_dir(&src_path, &dst_path)?;
        } else {
            fs::copy(&src_path, &dst_path)?;
        }
    }
    Ok(())
}

#[allow(dead_code)] // Re-enable alongside the auto-updater; only the version sidecar reads this.
fn esm_crate_version(git_path: &Path) -> String {
    let cargo_toml = git_path.join("src").join("esm").join("Cargo.toml");
    let Ok(contents) = fs::read_to_string(&cargo_toml) else {
        return "0.0.0".into();
    };

    for line in contents.lines() {
        let trimmed = line.trim();
        if let Some(rest) = trimmed.strip_prefix("version = \"") {
            if let Some(version) = rest.strip_suffix('"') {
                return version.to_string();
            }
        }
    }

    "0.0.0".into()
}
