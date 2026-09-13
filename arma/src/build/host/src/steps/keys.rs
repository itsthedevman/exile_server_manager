use std::{thread, time::Duration};

use redis::Commands;

use crate::{
    context::InstanceContext,
    error::{BuildError, BuildResult},
};

const REDIS_KEY: &str = "server_key";
const REDIS_KEY_CONFIRM: &str = "server_key_set";

/// The Redis slot this server watches for its key.
///
/// Named for the server so that several build processes can't steal each other's keys. Whoever issues a key
/// names the server it is for, the spec suite included: it used to publish to an unnamespaced slot, which the
/// first configured server also watched, so running the suite took whichever server that was off its own
/// connection.
fn key_slot(ictx: &InstanceContext) -> String {
    format!("{REDIS_KEY}:{}", ictx.instance.server_id)
}

/// Confirmation flag to set once a key has been written, mirroring [`key_slot`].
fn confirm_slot(ictx: &InstanceContext) -> String {
    format!("{REDIS_KEY_CONFIRM}:{}", ictx.instance.server_id)
}

/// Spawn a background thread that watches Redis for new server keys and writes
/// them into the container's `@esm/esm.key` (plus a `.RELOAD` trigger).
///
/// Returns immediately — the thread runs until the process exits.
pub fn start_key_exchange(ictx: &InstanceContext) -> BuildResult {
    let redis = redis::Client::open("redis://127.0.0.1/0")
        .map_err(|e| BuildError::Redis(e))?;

    let server_path = ictx.server_path().to_path_buf();
    let build_path = ictx.instance_staging_path();
    // Cloned rather than borrowed: this thread outlives the step that starts it, so it needs its own handle on
    // wherever the server lives.
    let target = ictx.target.clone();
    let read_slot = key_slot(ictx);
    let write_slot = confirm_slot(ictx);

    thread::spawn(move || {
        let mut conn = match redis.get_connection() {
            Ok(c) => c,
            Err(e) => {
                eprintln!("[keys] Redis connection failed: {e}");
                return;
            }
        };

        let mut last_key = String::new();

        // A key claimed from Redis but not yet written. Kept across a failed write, since claiming it took it out of
        // Redis and whoever issued it is waiting for the confirmation rather than issuing it again.
        let mut pending: Option<String> = None;

        loop {
            // Read destructively so a key is claimed exactly once, rather than being re-applied on every pass
            // until something else overwrites it. A newer key replaces one still waiting to be written.
            if let Some(issued) = conn.get_del::<_, Option<String>>(&read_slot).ok().flatten() {
                pending = Some(issued);
            }

            let Some(key) = pending.clone() else {
                thread::sleep(Duration::from_millis(100));
                continue;
            };

            if key == last_key {
                pending = None;
                thread::sleep(Duration::from_millis(100));
                continue;
            }

            let esm_dir = server_path.join("@esm");

            // The sentinel is what makes the extension re-read the key without a restart, so it goes second
            let key_path = esm_dir.join("esm.key");
            let reload_path = esm_dir.join(".RELOAD");

            if let Err(e) = target.write_files(&[(&key_path, key.as_bytes()), (&reload_path, b"true")]) {
                eprintln!("[keys] Failed to write server key, trying again: {e}");
                thread::sleep(Duration::from_secs(1));
                continue;
            }

            // Keep a host-side copy for inspection. It goes in this server's own staging directory: a shared
            // one would mean each server overwriting the others' keys, and a stale key riding into the wrong
            // container on the next deploy.
            if let Err(e) = std::fs::create_dir_all(&build_path)
                .and_then(|_| std::fs::write(build_path.join("esm.key"), key.as_bytes()))
            {
                eprintln!("[keys] Failed to write local key: {e}");
            }

            pending = None;
            last_key = key;

            let _: Result<(), _> = conn.set(&write_slot, "true");

            thread::sleep(Duration::from_millis(100));
        }
    });

    Ok(())
}
