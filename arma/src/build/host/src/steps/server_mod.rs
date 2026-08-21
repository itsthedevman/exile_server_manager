use std::{fs, path::Path};

use crate::{
    context::{BuildOS, InstanceContext},
    error::{BuildError, BuildResult},
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
