use std::{fs, path::Path};

use serde::{Deserialize, Serialize};

use crate::{
    context::BuildContext,
    error::{BuildError, BuildResult},
};

pub fn deploy(ctx: &mut BuildContext) -> BuildResult {
    let staging = ctx.local_build_path.join("@esm");
    let server_esm = ctx.target.server_path().join("@esm");

    // Write runtime config.yml into staging before uploading
    write_runtime_config(ctx, &staging)?;

    // If a key file was provided (release + start-server), copy it in
    if ctx.args.has_key_file() {
        fs::copy(ctx.args.key_file_path(), staging.join("esm.key"))?;
    }

    // Remove old @esm from the server, then copy the complete staging area in
    ctx.target.run(&format!("rm -rf '{}'", server_esm.display()))?;
    ctx.target.upload(&staging, ctx.target.server_path())?;

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

fn write_runtime_config(ctx: &BuildContext, staging: &Path) -> BuildResult {
    #[derive(Serialize, Deserialize)]
    struct RuntimeConfig {
        connection_uri: String,
        log_level: String,
        additional_logs: Vec<String>,
    }

    let config = RuntimeConfig {
        connection_uri: ctx.args.bot_host().to_string(),
        log_level: ctx.args.log_level().to_string(),
        additional_logs: vec!["test.log".to_string(), "/tmp/test.rpt".to_string()],
    };

    let yaml = serde_yaml::to_string(&config)?;
    fs::write(staging.join("config.yml"), yaml)?;

    Ok(())
}
