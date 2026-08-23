use std::{fs, path::Path};

use serde::{Deserialize, Serialize};

use crate::{
    context::{BuildContext, InstanceContext},
    error::{BuildError, BuildResult},
};

/// Where the fixture logs the `logs` command's specs search live locally.
const TEST_LOG_DIR: &str = "tools/server";

/// The server's authentication key. Named the same on both sides, since staging uploads it verbatim.
const SERVER_KEY_FILE: &str = "esm.key";

pub fn deploy(ictx: &InstanceContext) -> BuildResult {
    let staging = ictx.build.local_build_path.join("@esm");
    let server_esm = ictx.server_path().join("@esm");

    // Placed before the config is written, because the config is what claims they are there.
    let additional_logs = write_test_logs(ictx)?;

    // Write runtime config.yml into staging before uploading
    write_runtime_config(ictx, &staging, additional_logs)?;

    stage_server_key(ictx, &staging, &server_esm)?;

    // Empty the old deploy out rather than removing the directory: @esm is this server's bind mount, so the
    // mount point itself cannot be unlinked from inside the container.
    ictx.target.clear_directory(&server_esm)?;
    ictx.target.upload(&staging, &server_esm)?;

    Ok(())
}

pub fn package_release(ctx: &mut BuildContext) -> BuildResult {
    // For release builds, the staging area IS the output — nothing to copy.
    // The caller zips target/@esm/ directly.
    // Just confirm the staging area is present.
    let staging = ctx.local_build_path.join("@esm");
    if !staging.exists() {
        return Err(BuildError::General(
            "Release staging area target/@esm/ does not exist".into(),
        ));
    }

    Ok(())
}

/// Put the fixture logs the `logs` command's specs search for onto the target, and name them the way the
/// extension will be told to find them.
///
/// The two are listed differently on purpose. `additional_logs` accepts a path relative to the server root or an
/// absolute one, the extension resolves the two by different routes, and a server owner pointing at a log outside
/// the install is the reason the absolute form exists. Covering both here means a spec run exercises both.
///
/// They are written rather than mounted in: a container could have them handed over by the compose file, and a
/// Windows host reached over SSH has no equivalent, so it went looking for a `test.log` that had never been put
/// anywhere and failed every `logs` spec with "File does not exist".
fn write_test_logs(ictx: &InstanceContext) -> Result<Vec<String>, BuildError> {
    let fixtures = ictx.build.git_path.join(TEST_LOG_DIR);
    let server_root = ictx.server_path();

    let relative = "test.log";
    let absolute = server_root.join("test.rpt");

    ictx.target
        .write_file(&server_root.join(relative), &fs::read(fixtures.join(relative))?)?;

    ictx.target
        .write_file(&absolute, &fs::read(fixtures.join("test.rpt"))?)?;

    Ok(vec![relative.to_string(), absolute.display().to_string()])
}

fn write_runtime_config(
    ictx: &InstanceContext,
    staging: &Path,
    additional_logs: Vec<String>,
) -> BuildResult {
    #[derive(Serialize, Deserialize)]
    struct RuntimeConfig {
        connection_uri: String,
        log_level: String,
        additional_logs: Vec<String>,
    }

    let config = RuntimeConfig {
        connection_uri: ictx.bot_host().to_string(),
        log_level: ictx.args().log_level().to_string(),
        additional_logs,
    };

    let yaml = serde_yaml::to_string(&config)?;
    fs::write(staging.join("config.yml"), yaml)?;

    Ok(())
}

/// Carry the server's key into staging so that deploying does not take it away.
///
/// `esm.key` is not something staging builds. The bot publishes a key through Redis and the key exchange writes it
/// straight onto the target, so emptying `@esm` and uploading over it used to leave the server with no key at all:
/// the first boot after any deploy authenticated against nothing and logged `Invalid "esm.key" detected` until the
/// exchange caught up a few seconds later.
///
/// `--key-file` wins, since it is the one case where a key was named on purpose. Failing that, the key already on
/// the target comes across. Neither is final: the exchange starts after this and writes whatever Redis hands it
/// over the top, so a rotated key still lands.
fn stage_server_key(ictx: &InstanceContext, staging: &Path, server_esm: &Path) -> BuildResult {
    let staged = staging.join(SERVER_KEY_FILE);

    if ictx.args().has_key_file() {
        fs::copy(ictx.args().key_file_path(), &staged)?;
        return Ok(());
    }

    let deployed = server_esm.join(SERVER_KEY_FILE);

    // Staging is shared by every server, so a key sitting in it belongs to whichever one deployed last. Better
    // none than somebody else's: an absent key fails the boot check this is already expected to fail, while a
    // wrong one authenticates as another server until the exchange corrects it.
    if !ictx.target.exists(&deployed)? {
        if staged.exists() {
            fs::remove_file(&staged)?;
        }

        return Ok(());
    }

    ictx.target.download(&deployed, &staged)?;

    Ok(())
}
