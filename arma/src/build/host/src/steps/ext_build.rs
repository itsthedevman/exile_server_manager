use std::{
    fs,
    io::{BufRead, BufReader},
    process::{Command, Stdio},
    sync::{atomic::{AtomicUsize, Ordering}, Arc},
};

use crate::{
    context::{BuildArch, BuildContext, BuildOS, git_sha_short},
    display::print_subprocess_line,
    error::{BuildError, BuildResult},
    spinner::MultiSpinner,
    steps::detect::{extension_filename, updater_filename},
};

/// Linker def file giving the extension cdylibs the decorated export names Arma x86 looks for.
const WINDOWS_X86_EXPORTS: &str = "windows-x86-exports.def";

pub fn build_extension(ctx: &mut BuildContext) -> BuildResult {
    let mut sp = MultiSpinner::start("Building extension");
    let counter = sp.line_counter();

    let ext_name = extension_filename(ctx.args.build_arch(), ctx.args.build_os());
    let upd_name = updater_filename(ctx.args.build_arch(), ctx.args.build_os());

    sp.sub_start("esm", false);
    build_esm(ctx, &counter).map_err(|e| { sp.sub_fail(&ext_name, false); e })?;
    sp.sub_done(&ext_name, false);

    sp.sub_start("esm_updater", true);
    build_updater(ctx, &counter).map_err(|e| { sp.sub_fail(&upd_name, true); e })?;
    sp.sub_done(&upd_name, true);

    sp.done();
    Ok(())
}

fn build_esm(ctx: &BuildContext, counter: &Arc<AtomicUsize>) -> BuildResult {
    let extension_path = ctx.git_path.join("src").join("esm");

    fs::write(
        extension_path.join(".build-sha"),
        git_sha_short().as_bytes(),
    )?;

    let target = ctx.extension_build_target();
    let mut args = vec!["build", "--target", target];

    let features_flag;
    let release_flags: Vec<&str>;

    if ctx.args.release {
        release_flags = vec!["--release"];
    } else {
        features_flag = "--features=development";
        args.push(&features_flag);
        release_flags = vec![];
    }
    args.extend_from_slice(&release_flags);

    run_cargo(&args, &extension_path.to_string_lossy(), counter, &windows_rustflags(ctx))?;

    let build_dir = if ctx.args.release { "release" } else { "debug" };
    let src = match ctx.args.build_os() {
        BuildOS::Linux => ctx.git_path
            .join("target")
            .join(target)
            .join(build_dir)
            .join("libesm_arma.so"),
        BuildOS::Windows => ctx.git_path
            .join("target")
            .join(target)
            .join(build_dir)
            .join("esm_arma.dll"),
    };

    let dst_name = extension_filename(ctx.args.build_arch(), ctx.args.build_os());
    let dst = ctx.local_build_path.join("@esm").join(&dst_name);
    fs::copy(&src, &dst).map_err(|e| {
        BuildError::General(format!(
            "Failed to copy {} to {}: {e}",
            src.display(),
            dst.display()
        ))
    })?;

    Ok(())
}

fn build_updater(ctx: &BuildContext, counter: &Arc<AtomicUsize>) -> BuildResult {
    let updater_path = ctx.git_path.join("src").join("updater").join("extension");
    let target = ctx.extension_build_target();
    let mut args = vec!["build", "--target", target];

    let release_flags: Vec<&str> = if ctx.args.release {
        vec!["--release"]
    } else {
        vec![]
    };
    args.extend_from_slice(&release_flags);

    run_cargo(&args, &updater_path.to_string_lossy(), counter, &windows_rustflags(ctx))?;

    let build_dir = if ctx.args.release { "release" } else { "debug" };
    let src = match ctx.args.build_os() {
        BuildOS::Linux => ctx.git_path
            .join("target")
            .join(target)
            .join(build_dir)
            .join("libesm_updater.so"),
        BuildOS::Windows => ctx.git_path
            .join("target")
            .join(target)
            .join(build_dir)
            .join("esm_updater.dll"),
    };

    let dst_name = updater_filename(ctx.args.build_arch(), ctx.args.build_os());
    let dst = ctx.local_build_path.join("@esm").join(&dst_name);
    fs::copy(&src, &dst).map_err(|e| {
        BuildError::General(format!(
            "Failed to copy {} to {}: {e}",
            src.display(),
            dst.display()
        ))
    })?;

    Ok(())
}

/// Extra rustc flags a Windows extension needs, as `(variable, value)` pairs ready for the cargo environment.
///
/// Only one thing left here, and only for 32-bit: `src/windows-x86-exports.def` gives Arma the decorated export
/// names it looks for on x86. Without it `--x32 --target=windows` produces a server that loads no extension at
/// all and reports nothing about why. That file explains itself.
///
/// A `-C debug-assertions=off` workaround used to live here too, for an abort caused by arma-rs reading Arma's
/// unaligned argv as an aligned array reference. That is fixed properly in the fork now pinned in `Cargo.toml`,
/// so Windows debug builds keep their assertions like every other target.
///
/// Appended to the target-scoped variable rather than set as `RUSTFLAGS`, because the dev shell already exports it
/// to point the linker at winpthreads and the two do not merge: a plain `RUSTFLAGS` silently replaces it, and the
/// link then fails on a missing `libpthread.a`.
fn windows_rustflags(ctx: &BuildContext) -> Vec<(String, String)> {
    if !matches!(ctx.args.build_os(), BuildOS::Windows) {
        return vec![];
    }

    // 32-bit only, every profile: see the file itself for why Arma cannot find the entry points without it.
    if !matches!(ctx.args.build_arch(), BuildArch::X32) {
        return vec![];
    }

    let exports = ctx.git_path.join("src").join(WINDOWS_X86_EXPORTS);
    let flags = format!(" -C link-arg={}", exports.display());

    let variable = format!(
        "CARGO_TARGET_{}_RUSTFLAGS",
        ctx.extension_build_target().to_uppercase().replace('-', "_")
    );

    let existing = std::env::var(&variable).unwrap_or_default();

    vec![(variable, format!("{existing}{flags}"))]
}

/// Run `cargo <args>` in `working_dir`, streaming output through the tree pipe.
/// `counter` must be the line counter from the parent `MultiSpinner` so the
/// animation thread knows how many lines are below the header.
fn run_cargo(
    args: &[&str],
    working_dir: &str,
    counter: &Arc<AtomicUsize>,
    env: &[(String, String)],
) -> BuildResult {
    let mut child = Command::new("cargo")
        .args(args)
        .envs(env.iter().map(|(key, value)| (key.as_str(), value.as_str())))
        .current_dir(working_dir)
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .spawn()
        .map_err(|e| BuildError::General(format!("Failed to spawn cargo: {e}")))?;

    // Stream stderr (where cargo's progress goes) live
    if let Some(stderr) = child.stderr.take() {
        let reader = BufReader::new(stderr);
        for line in reader.lines().flatten() {
            print_subprocess_line(&line);
            counter.fetch_add(1, Ordering::Relaxed);
        }
    }

    let output = child
        .wait_with_output()
        .map_err(|e| BuildError::General(e.to_string()))?;

    if !output.status.success() {
        let stdout = String::from_utf8_lossy(&output.stdout);
        for line in stdout.lines() {
            if !line.trim().is_empty() {
                print_subprocess_line(line);
                counter.fetch_add(1, Ordering::Relaxed);
            }
        }
        return Err(BuildError::General(format!(
            "cargo {} failed (exit {})",
            args.first().unwrap_or(&""),
            output.status.code().unwrap_or(-1)
        )));
    }

    Ok(())
}
