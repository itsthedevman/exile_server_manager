use std::{fs, path::Path};

use serde::{Deserialize, Serialize};

use crate::{
    context::{BuildContext, InstanceContext},
    error::{BuildError, BuildResult},
};

pub fn deploy(ictx: &InstanceContext) -> BuildResult {
    let staging = ictx.build.local_build_path.join("@esm");
    let server_esm = ictx.server_path().join("@esm");

    // Write runtime config.yml into staging before uploading
    write_runtime_config(ictx, &staging)?;

    // If a key file was provided (release + start-server), copy it in
    if ictx.args().has_key_file() {
        fs::copy(ictx.args().key_file_path(), staging.join("esm.key"))?;
    }

    // Empty the old deploy out rather than removing the directory: @esm is this server's bind mount, so the
    // mount point itself cannot be unlinked from inside the container.
    ictx.target.run(&format!(
        "mkdir -p '{dir}' && find '{dir}' -mindepth 1 -delete",
        dir = server_esm.display()
    ))?;
    ictx.target.upload(&staging, &server_esm)?;

    Ok(())
}

pub fn package_release(ctx: &mut BuildContext) -> BuildResult {
    // For release builds, the staging area IS the output — nothing to copy.
    // The caller (bin/release) zips target/@esm/ directly.
    // Just confirm the staging area is present.
    let staging = ctx.local_build_path.join("@esm");
    if !staging.exists() {
        return Err(BuildError::General(
            "Release staging area target/@esm/ does not exist".into(),
        ));
    }

    Ok(())
}

fn write_runtime_config(ictx: &InstanceContext, staging: &Path) -> BuildResult {
    #[derive(Serialize, Deserialize)]
    struct RuntimeConfig {
        connection_uri: String,
        log_level: String,
        additional_logs: Vec<String>,
    }

    let config = RuntimeConfig {
        connection_uri: ictx.args().bot_host().to_string(),
        log_level: ictx.args().log_level().to_string(),
        additional_logs: vec!["test.log".to_string(), "/tmp/test.rpt".to_string()],
    };

    let yaml = serde_yaml::to_string(&config)?;
    fs::write(staging.join("config.yml"), yaml)?;

    Ok(())
}
