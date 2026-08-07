use std::{fs, path::Path};

use crate::{
    context::InstanceContext,
    error::{BuildError, BuildResult},
    target::docker,
};

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

    if !source.join("extdb3-conf.ini").exists() {
        return Err(BuildError::General(format!(
            "Missing @exileserver mod files in {}.\n\
             This directory ships with the repository and holds the Exile server mod.",
            source.display()
        )));
    }

    // Replace the contents rather than the directory: it is a bind mount, so the mount point itself cannot be
    // unlinked from inside the container.
    ictx.target.run(&format!(
        "mkdir -p '{dir}' && find '{dir}' -mindepth 1 -delete",
        dir = dest.display()
    ))?;
    ictx.target.upload(&source, &dest)?;

    let extdb_conf = render_extdb_conf(&source, &ictx.instance.database)?;
    docker::write_file(
        &ictx.container(),
        &dest.join("extdb3-conf.ini"),
        extdb_conf.as_bytes(),
    )?;

    let server_cfg = render_server_cfg(&source, &ictx.instance.server_id, ictx.instance.port)?;
    docker::write_file(
        &ictx.container(),
        &dest.join("config.cfg"),
        server_cfg.as_bytes(),
    )?;

    Ok(())
}

/// Point the `[exile]` section at this server's own database, leaving every other section untouched.
fn render_extdb_conf(source: &Path, database: &str) -> Result<String, BuildError> {
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
