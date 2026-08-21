use std::{fs, path::Path};

use crate::{
    context::{BuildOS, InstanceContext},
    display::print_subprocess_line,
    error::{BuildError, BuildResult},
    spinner::MultiSpinner,
};

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

/// Put the content a Linux container gets from a bind mount onto a target that has none.
///
/// docker-compose mounts `@exile` and `mpmissions` straight out of the repo, so a container never needs its own
/// copy and nothing in the build ever uploaded one. A remote host has no such trick: without this it starts with
/// `-mod=@exile;` naming a directory that does not exist, and Arma reports that as a missing addon rather than as
/// missing setup, which sends you looking in the wrong place.
///
/// Sent only when absent, because `@exile` is well over a gigabyte and changes about as often as Exile releases;
/// re-sending it every build would cost minutes to change nothing. `--full` forces it.
pub fn sync_shared_content(ictx: &InstanceContext) -> BuildResult {
    // Docker already mounted it. Nothing to do, and copying it in would shadow the mount with a stale duplicate.
    if matches!(ictx.args().build_os(), BuildOS::Linux) {
        return Ok(());
    }

    let source_root = ictx.build.git_path.join("tools").join("server");
    let mut pending = Vec::new();

    for name in SHARED_CONTENT {
        let source = source_root.join(name);

        if !source.exists() {
            return Err(BuildError::General(format!(
                "Missing {} in {}.\n\
                 A Windows server needs its own copy of this, since it has no bind mount to read it through.",
                name,
                source_root.display()
            )));
        }

        let dest = ictx.server_path().join(name);

        if ictx.args().full_rebuild() || !ictx.target.exists(&dest)? {
            pending.push((*name, source, dest));
        }
    }

    if pending.is_empty() {
        return Ok(());
    }

    // Its own spinner with a line per item: this is minutes of silence otherwise, and the size is the only
    // answer to "why is it stuck".
    let mut spinner = MultiSpinner::start("Syncing server content");
    let counter = spinner.line_counter();

    for (name, source, dest) in pending {
        print_subprocess_line(&format!("{name} ({}) -> {}", human_size(&source), dest.display()));
        counter.fetch_add(1, std::sync::atomic::Ordering::Relaxed);

        if let Err(e) = ictx.target.upload(&source, &dest) {
            spinner.sub_fail(name, true);
            return Err(e);
        }
    }

    spinner.done();
    Ok(())
}

/// Rough on-disk size of a directory tree, for telling someone why a step is going to take a while.
fn human_size(path: &Path) -> String {
    fn total(path: &Path) -> u64 {
        let Ok(entries) = fs::read_dir(path) else {
            return 0;
        };

        entries
            .filter_map(Result::ok)
            .map(|entry| match entry.file_type() {
                Ok(kind) if kind.is_dir() => total(&entry.path()),
                _ => entry.metadata().map(|meta| meta.len()).unwrap_or(0),
            })
            .sum()
    }

    let bytes = total(path) as f64;

    for (limit, unit) in [(1e9, "GB"), (1e6, "MB"), (1e3, "KB")] {
        if bytes >= limit {
            return format!("{:.1}{unit}", bytes / limit);
        }
    }

    format!("{bytes:.0}B")
}
