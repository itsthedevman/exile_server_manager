use std::{fs, path::Path};

use compiler::Compiler;
use glob::glob;

use crate::{
    compile::bind_replacements,
    context::BuildContext,
    display::print_subprocess_line,
    error::{BuildError, BuildResult},
    spinner::MultiSpinner,
    string_table,
    ADDONS,
};

pub fn build_mod(ctx: &mut BuildContext) -> BuildResult {
    let source_path = ctx.git_path.join("src").join("@esm");
    let build_path = ctx.local_build_path.join("@esm");

    let has_test = !ctx.args.release;
    let addon_count = ADDONS.len() + if has_test { 1 } else { 0 };

    let mut sp = MultiSpinner::start("Building mod");

    // Sub-steps: compile, stringtable, sqf check, pack
    compile_sqf(ctx, &source_path, &build_path)
        .map_err(|e| { sp.sub_fail("Replacing macros", false); e })?;
    sp.sub_done("Replacing macros", false);

    string_table::convert_yaml_to_xml(
        build_path.join("addons").join("exile_server_manager").join("stringtable.yml"),
    )
    .map_err(|e| BuildError::General(e))?;

    // Write stringtable.xml was done by convert_yaml_to_xml internally
    sp.sub_done("Building stringtable.xml", false);

    check_sqf(&build_path, ctx)
        .map_err(|e| { sp.sub_fail("Checking SQF", false); e })?;
    sp.sub_done("Checking SQF", false);

    pack_addons(ctx, &build_path, has_test)
        .map_err(|e| { sp.sub_fail("Packing addons", false); e })?;
    sp.sub_done(&format!("Packing {} addons", addon_count), false);

    copy_extras(ctx, &source_path, &build_path)
        .map_err(|e| { sp.sub_fail("Copying extras", true); e })?;
    sp.sub_done("Copying extras", true);

    sp.done();
    Ok(())
}

fn compile_sqf(
    ctx: &BuildContext,
    source_path: &Path,
    dest_path: &Path,
) -> BuildResult {
    let target_str = ctx.args.build_os().to_string();

    for (src, dst) in [
        (source_path.join("addons"), dest_path.join("addons")),
        (source_path.join("optionals"), dest_path.join("optionals")),
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

fn check_sqf(build_path: &Path, ctx: &BuildContext) -> BuildResult {
    let pattern = format!("{}/**/*.sqf", build_path.display());
    let sqfvm = ctx.git_path.join("bin").join("sqfvm");

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

    Ok(())
}

fn pack_addons(
    ctx: &BuildContext,
    build_path: &Path,
    include_test: bool,
) -> BuildResult {
    let armake2 = ctx.git_path.join("bin").join("armake2");
    let addons_path = build_path.join("addons");

    let mut addons: Vec<&str> = ADDONS.to_vec();
    if include_test {
        addons.push("esm_test");
    }

    for addon in &addons {
        if !ctx.rebuild_addon(addon) {
            continue;
        }

        let src = addons_path.join(addon);
        let dst = addons_path.join(format!("{addon}.pbo"));

        let output = std::process::Command::new(&armake2)
            .args(["pack", "-v", &src.to_string_lossy(), &dst.to_string_lossy()])
            .output()
            .map_err(|e| BuildError::General(e.to_string()))?;

        let stderr = String::from_utf8_lossy(&output.stderr);
        let stdout = String::from_utf8_lossy(&output.stdout);

        // Print armake2 output lines with tree indentation
        for line in stdout.lines().chain(stderr.lines()) {
            if !line.trim().is_empty() {
                print_subprocess_line(line);
            }
        }

        if !output.status.success() || stdout.contains("ErrorId") || stderr.contains("missing file") {
            return Err(BuildError::General(format!(
                "Failed to pack {addon}: {}",
                stderr.trim()
            )));
        }

        if !dst.exists() {
            return Err(BuildError::General(format!(
                "armake2 produced no output for {addon}"
            )));
        }
    }

    Ok(())
}

fn copy_extras(
    ctx: &BuildContext,
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

    // version sidecar (read from src/esm/Cargo.toml)
    let version = esm_crate_version(&ctx.git_path);
    fs::write(build_path.join("version"), format!("{version}\n"))?;

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
