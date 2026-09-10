use std::{fs, path::Path};

use crate::{
    context::{BuildOS, InstanceContext},
    error::{BuildError, BuildResult},
    spinner::MultiSpinner,
};

/// Files that belong in the Arma server root on Windows, as a directory under `tools/server`.
///
/// Separate from the mod content because where a file goes is the whole point: extDB3's allocator has to sit
/// next to `arma3server.exe`, since Windows resolves a DLL's dependencies against the process directory rather
/// than against the directory the extension was loaded from.
const WINDOWS_ROOT_CONTENT: &str = "windows";

/// Content the Linux container gets from a bind mount, named relative to `tools/server`.
///
/// `@exileserver` is deliberately absent: it is rewritten per server and uploaded by [`prepare_server_mod`]
/// every build, which is a different job with a different cadence.
const SHARED_CONTENT: &[&str] = &["@exile", "mpmissions"];

/// Section of `extdb3-conf.ini` holding the Exile database connection.
const EXTDB_SECTION: &str = "[exile]";

/// Lay down this server's own copy of `@exileserver`.
///
/// The mod is identical for every server; two files inside it are not. `extdb3-conf.ini` names the Exile
/// database, and `config.cfg` names the server, so both are rewritten per server after the copy. Giving each
/// server its own copy also stops them sharing one `logs/` directory, which used to be written straight back
/// into the git tree.
pub fn prepare_server_mod(ictx: &InstanceContext) -> BuildResult {
    let source = ictx
        .build
        .git_path
        .join("tools")
        .join("server")
        .join("@exileserver");
    let dest = ictx.server_path().join("@exileserver");

    if matches!(ictx.args().build_os(), BuildOS::Windows) && ictx.database_host().is_none() {
        return Err(BuildError::Config(
            "A Windows server needs `windows.database_host` in config.yml: the address it reaches the Exile \
             database on. The shipped extdb3-conf.ini names `mysql_db`, which only resolves inside Docker's \
             own network, so a host outside it would deploy a config pointing at a name that does not exist."
                .into(),
        ));
    }

    if !source.join("extdb3-conf.ini").exists() {
        return Err(BuildError::General(format!(
            "Missing @exileserver mod files in {}.\n\
             This directory ships with the repository and holds the Exile server mod.",
            source.display()
        )));
    }

    // Replace the contents rather than the directory: it is a bind mount, so the mount point itself cannot be
    // unlinked from inside the container.
    ictx.target.clear_directory(&dest)?;
    ictx.target.upload(&source, &dest)?;

    let extdb_conf = render_extdb_conf(&source, &ictx.instance.database, ictx.database_host())?;
    ictx.target
        .write_file(&dest.join("extdb3-conf.ini"), extdb_conf.as_bytes())?;

    let server_cfg = render_server_cfg(&source, &ictx.instance.server_id, ictx.instance.port)?;
    ictx.target
        .write_file(&dest.join("config.cfg"), server_cfg.as_bytes())?;

    Ok(())
}

/// Point the `[exile]` section at this server's own database, leaving every other section untouched.
///
/// `host` rewrites the address too, which only a target outside the Docker network needs; `None` keeps whatever
/// the shipped file names.
fn render_extdb_conf(
    source: &Path,
    database: &str,
    host: Option<&str>,
) -> Result<String, BuildError> {
    let contents = fs::read_to_string(source.join("extdb3-conf.ini"))?;
    let mut in_exile_section = false;
    let mut rendered = String::with_capacity(contents.len());

    for line in contents.lines() {
        let trimmed = line.trim();

        if trimmed.starts_with('[') {
            in_exile_section = trimmed == EXTDB_SECTION;
        }

        if in_exile_section && trimmed.starts_with("Database") {
            rendered.push_str(&format!("Database = {database}\n"));
            continue;
        }

        if in_exile_section && trimmed.starts_with("IP") {
            if let Some(host) = host {
                rendered.push_str(&format!("IP = {host}\n"));
                continue;
            }
        }

        rendered.push_str(line);
        rendered.push('\n');
    }

    Ok(rendered)
}

/// Give the server a hostname that identifies it, so several running at once stay tellable apart in the
/// Steam server browser and in the website's A2S panel.
fn render_server_cfg(
    source: &Path,
    server_id: &str,
    port: u16,
) -> Result<String, BuildError> {
    let contents = fs::read_to_string(source.join("config.cfg"))?;
    let mut rendered = String::with_capacity(contents.len());

    for line in contents.lines() {
        if line.trim_start().starts_with("hostname") {
            rendered.push_str(&format!("hostname = \"ESM Dev | {server_id} | :{port}\";\n"));
            continue;
        }

        rendered.push_str(line);
        rendered.push('\n');
    }

    Ok(rendered)
}

/// Put the content a target has no bind mount for into its server root.
///
/// docker-compose mounts `@exile` and `mpmissions` straight out of the repo, so a container never needs its own
/// copy and copying them in would shadow the mount with a stale duplicate. A remote host has no such trick:
/// without this it starts with `-mod=@exile;` naming a directory that does not exist, and Arma reports that as a
/// missing addon rather than as missing setup, which sends you looking in the wrong place.
///
/// Discovered mods go to every target, container included. They are named on the launch line the moment they
/// appear in `tools/server`, and giving each one a mount of its own would mean editing docker-compose.yml for
/// every mod, which is the hand step this exists to remove.
///
/// Sent only when the target does not already have this exact content, because `@exile` is well over a gigabyte
/// and changes about as often as Exile releases. `--full` forces it.
pub fn sync_shared_content(ictx: &InstanceContext) -> BuildResult {
    let source_root = ictx.build.git_path.join("tools").join("server");
    let mut names: Vec<String> = Vec::new();

    if matches!(ictx.args().build_os(), BuildOS::Windows) {
        for name in SHARED_CONTENT {
            if !source_root.join(name).exists() {
                return Err(BuildError::General(format!(
                    "Missing {} in {}.\n\
                     A Windows server needs its own copy of this, since it has no bind mount to read it through.",
                    name,
                    source_root.display()
                )));
            }

            names.push((*name).to_string());
        }
    }

    names.extend(ictx.build.extra_mods.all().cloned());

    let mut pending = Vec::new();

    for name in names {
        let source = source_root.join(&name);
        let (files, bytes) = measure(&source);

        // Keyed on what the source holds, not on whether the destination exists. Arma's own install creates
        // `mpmissions` with a readme in it, so a destination that exists says nothing about whether the mission
        // is in there: checking existence skipped the upload and left the server with no mission to load.
        // Putting the fingerprint in the name means a changed source is a name that is simply not there yet.
        let stamp = ictx
            .target
            .build_path()
            .join("sync")
            .join(format!("{name}-{files}-{bytes}.stamp"));

        if ictx.args().full_rebuild() || !ictx.target.exists(&stamp)? {
            let dest = ictx.server_path().join(&name);
            pending.push((name, source, dest, stamp, bytes));
        }
    }

    if pending.is_empty() {
        return Ok(());
    }

    // Its own spinner with a line per item: this is minutes of silence otherwise, and the size is the only
    // answer to "why is it stuck".
    let mut spinner = MultiSpinner::start("Syncing server content");
    let sub_lines = spinner.sub_lines();

    for (name, source, dest, stamp, bytes) in pending {
        sub_lines.print(&format!("{name} ({}) -> {}", human_size(bytes), dest.display()));

        if let Err(e) = ictx.target.upload(&source, &dest) {
            spinner.sub_fail(&name, true);
            return Err(e);
        }

        // Written only after the upload returns, so an interrupted transfer is retried rather than remembered
        // as done.
        if let Err(e) = ictx.target.write_file(&stamp, b"") {
            spinner.sub_fail(&name, true);
            return Err(e);
        }
    }

    spinner.done();
    Ok(())
}

/// Count the files in a tree and add up their sizes, which together are enough to notice a source has changed.
fn measure(path: &Path) -> (u64, u64) {
    let Ok(entries) = fs::read_dir(path) else {
        return (0, 0);
    };

    entries
        .filter_map(Result::ok)
        .fold((0, 0), |(files, bytes), entry| match entry.file_type() {
            Ok(kind) if kind.is_dir() => {
                let (sub_files, sub_bytes) = measure(&entry.path());
                (files + sub_files, bytes + sub_bytes)
            }
            _ => (
                files + 1,
                bytes + entry.metadata().map(|meta| meta.len()).unwrap_or(0),
            ),
        })
}

/// Size in the largest unit that leaves a number worth reading, for telling someone why a step will take a while.
fn human_size(bytes: u64) -> String {
    let bytes = bytes as f64;

    for (limit, unit) in [(1e9, "GB"), (1e6, "MB"), (1e3, "KB")] {
        if bytes >= limit {
            return format!("{:.1}{unit}", bytes / limit);
        }
    }

    format!("{bytes:.0}B")
}

/// Put the Windows-only files that belong beside `arma3server.exe` into the server root.
///
/// Only extDB3's allocator so far. Linux needs no equivalent: extDB3 is a `.so` there with nothing to place
/// alongside it, which is why this has no counterpart on the container target rather than being a no-op there.
pub fn install_windows_runtime(ictx: &InstanceContext) -> BuildResult {
    if matches!(ictx.args().build_os(), BuildOS::Linux) {
        return Ok(());
    }

    let source = ictx
        .build
        .git_path
        .join("tools")
        .join("server")
        .join(WINDOWS_ROOT_CONTENT);

    if !source.exists() {
        return Err(BuildError::General(format!(
            "Missing {}.\n\
             It holds the files that belong next to arma3server.exe, which currently means extDB3's allocator.\n\
             Without them extDB3 cannot load and Exile shuts the server down reporting the extension missing.",
            source.display()
        )));
    }

    // Straight into the root every time. It is a few hundred kilobytes, and skipping it on a stamp would mean
    // an operator who cleaned out the server directory gets the failure this exists to prevent.
    ictx.target.upload(&source, ictx.server_path())?;

    Ok(())
}

