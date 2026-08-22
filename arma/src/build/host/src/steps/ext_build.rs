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
/// Two unrelated problems, both specific to a Windows target and neither visible on Linux.
///
/// The first is the debug profile. Arma hands `RVExtensionArgs` an argv pointer that is only 4-byte aligned, and
/// arma-rs reads it as
/// `&[*mut c_char; N]`, which Rust requires to be 8-byte aligned. x86-64 loads it happily either way, so a release
/// build never notices, but with debug assertions on the compiler's alignment check turns that read into a
/// *non-unwinding* panic: the server aborts with `0xc0000409` on the first call into the extension, before any of
/// ESM's own code runs. Nothing on our side can satisfy the check, since the pointer belongs to Arma.
///
/// Overflow checks are the half of `debug-assertions` worth keeping, so they go back on by hand instead of
/// following it off. The updater is built the same way despite currently exposing only a zero-argument command,
/// which takes a branch that never touches the pointer: the constraint belongs to the platform, not to one crate,
/// and the first argument added to `check_update` would otherwise resurrect this.
///
/// The second is 32-bit only, applies to every profile, and is why `--x32 --target=windows` produced a server
/// that loaded no extension at all: `src/windows-x86-exports.def` gives Arma the decorated export names it looks
/// for on x86. That file explains itself.
///
/// Appended to the target-scoped variable rather than set as `RUSTFLAGS`, because the dev shell already exports it
/// to point the linker at winpthreads and the two do not merge: a plain `RUSTFLAGS` silently replaces it, and the
/// link then fails on a missing `libpthread.a`.
fn windows_rustflags(ctx: &BuildContext) -> Vec<(String, String)> {
    if !matches!(ctx.args.build_os(), BuildOS::Windows) {
        return vec![];
    }

    let mut flags = String::new();

    // Only the debug profile carries the alignment check described above, and release already has overflow
    // checks off, so turning them back on there would change what a release build means.
    if !ctx.args.release {
        flags.push_str(" -C debug-assertions=off -C overflow-checks=on");
    }

    // 32-bit only: see the file itself for why Arma cannot find the entry points without it.
    if matches!(ctx.args.build_arch(), BuildArch::X32) {
        let exports = ctx.git_path.join("src").join(WINDOWS_X86_EXPORTS);
        flags.push_str(&format!(" -C link-arg={}", exports.display()));
    }

    if flags.is_empty() {
        return vec![];
    }

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
