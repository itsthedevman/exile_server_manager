use std::{thread, time::Duration};

use redis::Commands;

use crate::{
    context::InstanceContext,
    error::{BuildError, BuildResult},
};

const REDIS_KEY: &str = "server_key";
const REDIS_KEY_CONFIRM: &str = "server_key_set";

/// The Redis slots this server watches for its key, most specific first.
///
/// Each server has its own slot so that several build processes can't steal each other's keys. The first
/// server configured also watches the unnamespaced slot, which is the one the spec suite writes to: its
/// server is built by a factory, so its server_id is random and no config could name the slot in advance.
fn key_slots(ictx: &InstanceContext) -> Vec<String> {
    let mut slots = vec![format!("{REDIS_KEY}:{}", ictx.instance.server_id)];

    if ictx.is_default_instance() {
        slots.push(REDIS_KEY.to_string());
    }

    slots
}

/// Confirmation flags to set once a key has been written, mirroring [`key_slots`].
fn confirm_slots(ictx: &InstanceContext) -> Vec<String> {
    let mut slots = vec![format!("{REDIS_KEY_CONFIRM}:{}", ictx.instance.server_id)];

    if ictx.is_default_instance() {
        slots.push(REDIS_KEY_CONFIRM.to_string());
    }

    slots
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
    let read_slots = key_slots(ictx);
    let write_slots = confirm_slots(ictx);

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
            // Reading destructively is what keeps the two slots from fighting: a key is claimed once, so the
            // namespaced slot can't re-assert a stale value over one the spec suite just published.
            let key = read_slots.iter().find_map(|slot| {
                conn.get_del::<_, Option<String>>(slot).ok().flatten()
            });

            let Some(key) = key else {
                thread::sleep(Duration::from_millis(100));
                continue;
            };

            if key == last_key {
                thread::sleep(Duration::from_millis(100));
                continue;
            }

            let esm_dir = server_path.join("@esm");

            if let Err(e) = target
                .write_file(&esm_dir.join("esm.key"), key.as_bytes())
                .and_then(|_| {
                    // The sentinel is what makes the extension re-read the key without a restart.
                    target.write_file(&esm_dir.join(".RELOAD"), b"true")
                })
            {
                eprintln!("[keys] Failed to write server key: {e}");
                thread::sleep(Duration::from_millis(100));
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

            last_key = key;

            for slot in &write_slots {
                let _: Result<(), _> = conn.set(slot, "true");
            }

            thread::sleep(Duration::from_millis(100));
        }
    });

    Ok(())
}
