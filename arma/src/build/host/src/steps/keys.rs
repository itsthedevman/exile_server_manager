use std::{
    io::Write,
    process::{Command, Stdio},
    thread,
    time::Duration,
};

use redis::Commands;

use crate::{
    context::BuildContext,
    error::{BuildError, BuildResult},
    ARMA_CONTAINER,
};

const REDIS_KEY: &str = "server_key";
const REDIS_KEY_CONFIRM: &str = "server_key_set";

/// Spawn a background thread that watches Redis for new server keys and writes
/// them into the container's `@esm/esm.key` (plus a `.RELOAD` trigger).
///
/// Returns immediately — the thread runs until the process exits.
pub fn start_key_exchange(ctx: &mut BuildContext) -> BuildResult {
    let redis = redis::Client::open("redis://127.0.0.1/0")
        .map_err(|e| BuildError::Redis(e))?;

    let server_path = ctx.target.server_path().to_path_buf();
    let build_path = ctx.local_build_path.join("@esm");

    thread::spawn(move || {
        let mut conn = match redis.get_connection() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("[keys] Redis connection failed: {e}");
                return;
            }
        };

        let mut last_key = String::new();

        loop {
            let key: Option<String> = match conn.get_del(REDIS_KEY) {
                Ok(k) => k,
                Err(_) => {
                    thread::sleep(Duration::from_millis(100));
                    continue;
                }
            };

            let Some(key) = key else {
                thread::sleep(Duration::from_millis(100));
                continue;
            };

            if key == last_key {
                thread::sleep(Duration::from_millis(100));
                continue;
            }

            // Write key file inside container — pipe key via stdin to avoid
            // any shell escaping issues with special characters in the key.
            let server_key_path = server_path.join("@esm").join("esm.key");
            let reload_path = server_path.join("@esm").join(".RELOAD");

            let write_cmd = format!(
                "cat > '{key_path}' && printf 'true' > '{reload}'",
                key_path = server_key_path.display(),
                reload = reload_path.display(),
            );

            if let Err(e) = run_in_container_with_stdin(&write_cmd, key.as_bytes()) {
                eprintln!("[keys] Failed to write server key: {e}");
                thread::sleep(Duration::from_millis(100));
                continue;
            }

            // Also write to local build staging
            if let Err(e) = std::fs::write(build_path.join("esm.key"), key.as_bytes()) {
                eprintln!("[keys] Failed to write local key: {e}");
            }

            last_key = key;

            let _: Result<(), _> = conn.set(REDIS_KEY_CONFIRM, "true");

            thread::sleep(Duration::from_millis(100));
        }
    });

    Ok(())
}

fn run_in_container_with_stdin(cmd: &str, input: &[u8]) -> Result<(), BuildError> {
    let mut child = Command::new("docker")
        .args(["exec", "-i", ARMA_CONTAINER, "/bin/bash", "-c", cmd])
        .stdin(Stdio::piped())
        .spawn()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if let Some(mut stdin) = child.stdin.take() {
        stdin
            .write_all(input)
            .map_err(|e| BuildError::Docker(e.to_string()))?;
    }

    let status = child
        .wait()
        .map_err(|e| BuildError::Docker(e.to_string()))?;

    if !status.success() {
        return Err(BuildError::Docker(format!(
            "docker exec failed (exit {:?})",
            status.code()
        )));
    }

    Ok(())
}
