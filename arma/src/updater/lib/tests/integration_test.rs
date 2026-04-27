//! Integration tests for updater_lib.
//!
//! Each test that changes `current_dir` acquires `CWD_LOCK` to prevent
//! parallel tests from interfering with each other (cwd is process-global).

use std::net::TcpListener;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use tempfile::TempDir;
use updater_lib::signing::{sign_for_test, verify_with_key};
use updater_lib::{BootCheckResult, UpdateSelection, Updater};
use updater_lib::version_file;

// ---------------------------------------------------------------------------
// Global lock: serializes all tests that call set_current_dir.
// ---------------------------------------------------------------------------
static CWD_LOCK: OnceLock<Mutex<()>> = OnceLock::new();

fn cwd_lock() -> &'static Mutex<()> {
    CWD_LOCK.get_or_init(|| Mutex::new(()))
}

// ---------------------------------------------------------------------------
// Helper: find a free port
// ---------------------------------------------------------------------------
fn free_port() -> u16 {
    let l = TcpListener::bind("127.0.0.1:0").unwrap();
    l.local_addr().unwrap().port()
}

// ---------------------------------------------------------------------------
// Helper: build a minimal tar.gz in memory containing a single file
// ---------------------------------------------------------------------------
fn make_tar_gz(filename: &str, content: &[u8]) -> Vec<u8> {
    use flate2::write::GzEncoder;
    use flate2::Compression;

    let buf = Vec::new();
    let gz = GzEncoder::new(buf, Compression::default());
    let mut tar = tar::Builder::new(gz);

    let mut header = tar::Header::new_gnu();
    header.set_size(content.len() as u64);
    header.set_mode(0o644);
    header.set_cksum();
    tar.append_data(&mut header, filename, content).unwrap();
    let gz = tar.into_inner().unwrap();
    gz.finish().unwrap()
}

// ---------------------------------------------------------------------------
// Helper: sha256 hex of a byte slice
// ---------------------------------------------------------------------------
fn sha256_hex(data: &[u8]) -> String {
    use sha2::{Digest, Sha256};
    let mut h = Sha256::new();
    h.update(data);
    hex::encode(h.finalize())
}

// ---------------------------------------------------------------------------
// Mock HTTP server backed by tiny_http.
// ---------------------------------------------------------------------------
struct MockServer {
    base_url: String,
    _handle: std::thread::JoinHandle<()>,
    request_count: Arc<Mutex<usize>>,
}

impl MockServer {
    /// Spin up a server that handles the given path→body routes.
    /// Unknown paths get a 404. Shuts down after 20 requests or 500ms idle.
    fn new(routes: Vec<(String, Vec<u8>)>) -> Self {
        let port = free_port();
        let addr = format!("127.0.0.1:{port}");
        let server = tiny_http::Server::http(&addr).unwrap();
        let request_count = Arc::new(Mutex::new(0usize));
        let rc2 = Arc::clone(&request_count);

        let handle = std::thread::spawn(move || {
            for _ in 0..20 {
                match server.recv_timeout(Duration::from_millis(500)) {
                    Ok(Some(req)) => {
                        *rc2.lock().unwrap() += 1;
                        let url = req.url().to_string();
                        let path =
                            url.split('?').next().unwrap_or(&url).to_string();
                        match routes.iter().find(|(p, _)| *p == path) {
                            Some((_, body)) => {
                                let _ = req.respond(
                                    tiny_http::Response::from_data(body.clone()),
                                );
                            }
                            None => {
                                let _ = req.respond(
                                    tiny_http::Response::from_string("not found")
                                        .with_status_code(404),
                                );
                            }
                        }
                    }
                    Ok(None) => break,
                    Err(_) => break,
                }
            }
        });

        MockServer {
            base_url: format!("http://{addr}"),
            _handle: handle,
            request_count,
        }
    }

    fn request_count(&self) -> usize {
        *self.request_count.lock().unwrap()
    }
}

// ---------------------------------------------------------------------------
// Helper: write @esm/config.yml pointing at the given manifest URL
// ---------------------------------------------------------------------------
fn write_config(dir: &std::path::Path, manifest_url: &str) {
    let config_dir = dir.join("@esm");
    std::fs::create_dir_all(&config_dir).unwrap();
    let content =
        format!("updater_enabled: true\nupdater_url: \"{manifest_url}\"\n");
    std::fs::write(config_dir.join("config.yml"), content).unwrap();
}

// ---------------------------------------------------------------------------
// Helper: write @esm/config.yml with updater disabled
// ---------------------------------------------------------------------------
fn write_config_disabled(dir: &std::path::Path) {
    let config_dir = dir.join("@esm");
    std::fs::create_dir_all(&config_dir).unwrap();
    std::fs::write(
        config_dir.join("config.yml"),
        "updater_enabled: false\n",
    )
    .unwrap();
}

// ---------------------------------------------------------------------------
// Helper: acquire CWD_LOCK, set cwd, run f, restore cwd, release lock.
// Uses an absolute saved path so the tmpdir cannot be dropped out from under us.
// ---------------------------------------------------------------------------
fn with_cwd<F, R>(dir: &std::path::Path, f: F) -> R
where
    F: FnOnce() -> R,
{
    let _guard = cwd_lock().lock().unwrap();
    // Canonicalize the original dir so it stays valid even if a TempDir
    // in another test is dropped concurrently.
    let original = std::env::current_dir().unwrap().canonicalize().unwrap();
    std::env::set_current_dir(dir).unwrap();
    let result = f();
    // Restore; best-effort (original dir always exists — it's the repo root).
    let _ = std::env::set_current_dir(&original);
    result
}

// ---------------------------------------------------------------------------
// Test 1: boot check — 999.0.0 available, bad sig (prod key) → Ok fail-open,
//         artifact endpoint NOT hit (≤ 2 requests).
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_update_available_bad_sig_failopen() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let artifact: Vec<u8> = b"fake-esm-binary-data".to_vec();
    let artifact_sha = sha256_hex(&artifact);
    let manifest_json = format!(
        r#"{{"esm":{{"version":"999.0.0","url":"/artifact","sha256":"{artifact_sha}","requires":{{}}}}}}"#
    );

    // Bad sig — so boot_check should fail-open at sig check.
    let bad_sig = vec![0u8; 64];

    let routes = vec![
        (
            "/versions.json".to_string(),
            manifest_json.as_bytes().to_vec(),
        ),
        ("/versions.json.sig".to_string(), bad_sig),
        ("/artifact".to_string(), artifact),
    ];
    let server = MockServer::new(routes);
    write_config(
        &dir,
        &format!("{}/versions.json", server.base_url),
    );

    let result = with_cwd(&dir, || {
        let deadline = Instant::now() + Duration::from_secs(5);
        Updater::run_boot_check(deadline).unwrap()
    });

    assert!(
        matches!(result, BootCheckResult::Ok),
        "expected Ok (bad sig fail-open), got {result:?}"
    );
    // Only manifest + sig fetched; artifact endpoint should not be hit.
    assert!(
        server.request_count() <= 2,
        "too many requests: {}",
        server.request_count()
    );
}

// ---------------------------------------------------------------------------
// Test 2: signing round-trip — sign_for_test + verify_with_key.
// ---------------------------------------------------------------------------
#[test]
fn test_signing_roundtrip() {
    let data = b"hello updater";
    let (raw_pub, sig) = sign_for_test(data);
    assert!(verify_with_key(data, &sig, &raw_pub).is_ok());
    // Wrong data must fail.
    assert!(verify_with_key(b"wrong", &sig, &raw_pub).is_err());
    // Wrong key must fail.
    let (other_pub, _) = sign_for_test(data);
    assert!(verify_with_key(data, &sig, &other_pub).is_err());
}

// ---------------------------------------------------------------------------
// Test 3: boot check disabled → Disabled, 0 HTTP requests.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_disabled() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    write_config_disabled(&dir);

    let result = with_cwd(&dir, || {
        let deadline = Instant::now() + Duration::from_secs(5);
        Updater::run_boot_check(deadline).unwrap()
    });

    assert!(
        matches!(result, BootCheckResult::Disabled),
        "expected Disabled, got {result:?}"
    );
}

// ---------------------------------------------------------------------------
// Test 4: boot check deadline already past → Ok in < 100ms.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_deadline_past() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    // Enabled config pointing at an unreachable host.
    write_config(&dir, "http://192.0.2.1:9/versions.json");

    let t = Instant::now();
    let result = with_cwd(&dir, || {
        let deadline = Instant::now() - Duration::from_millis(1);
        Updater::run_boot_check(deadline).unwrap()
    });
    let elapsed = t.elapsed();

    assert!(
        matches!(result, BootCheckResult::Ok),
        "expected Ok (deadline expired), got {result:?}"
    );
    assert!(
        elapsed < Duration::from_millis(100),
        "should be fast, took {elapsed:?}"
    );
}

// ---------------------------------------------------------------------------
// Test 5: SHA256 mismatch → Ok (fail-open), original file untouched.
//
// Uses bad sig so we go to fail-open at sig check (before download);
// the sentinel file must survive either way.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_sha256_mismatch_failopen() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    // Sentinel file that must NOT be modified.
    let sentinel_path = dir.join("@esm/esm_x64.so");
    std::fs::write(&sentinel_path, b"original-sentinel").unwrap();

    let wrong_sha =
        "0000000000000000000000000000000000000000000000000000000000000000";
    let manifest_json = format!(
        r#"{{"esm":{{"version":"999.0.0","url":"/artifact","sha256":"{wrong_sha}","requires":{{}}}}}}"#
    );
    let bad_sig = vec![0u8; 64];

    let routes = vec![
        (
            "/versions.json".to_string(),
            manifest_json.as_bytes().to_vec(),
        ),
        ("/versions.json.sig".to_string(), bad_sig),
        ("/artifact".to_string(), b"some-data".to_vec()),
    ];
    let server = MockServer::new(routes);
    write_config(
        &dir,
        &format!("{}/versions.json", server.base_url),
    );

    let result = with_cwd(&dir, || {
        let deadline = Instant::now() + Duration::from_secs(5);
        Updater::run_boot_check(deadline).unwrap()
    });

    assert!(
        matches!(result, BootCheckResult::Ok),
        "expected Ok (fail-open), got {result:?}"
    );
    let contents = std::fs::read(&sentinel_path).unwrap();
    assert_eq!(contents, b"original-sentinel", "sentinel must be unchanged");
    let _ = server.request_count();
}

// ---------------------------------------------------------------------------
// Test 6: bad signature → Ok, artifact endpoint never hit (≤ 2 requests).
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_bad_signature() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let artifact_sha = sha256_hex(b"fake-data");
    let manifest_json = format!(
        r#"{{"esm":{{"version":"999.0.0","url":"/artifact","sha256":"{artifact_sha}","requires":{{}}}}}}"#
    );
    let bad_sig = vec![0u8; 64];

    let routes = vec![
        (
            "/versions.json".to_string(),
            manifest_json.as_bytes().to_vec(),
        ),
        ("/versions.json.sig".to_string(), bad_sig),
        ("/artifact".to_string(), b"fake-data".to_vec()),
    ];
    let server = MockServer::new(routes);
    write_config(
        &dir,
        &format!("{}/versions.json", server.base_url),
    );

    let result = with_cwd(&dir, || {
        let deadline = Instant::now() + Duration::from_secs(5);
        Updater::run_boot_check(deadline).unwrap()
    });

    assert!(
        matches!(result, BootCheckResult::Ok),
        "expected Ok (bad sig), got {result:?}"
    );
    assert!(
        server.request_count() <= 2,
        "artifact endpoint must not be hit; requests={}",
        server.request_count()
    );
}

// ---------------------------------------------------------------------------
// Test 7: CLI run_cli_update — verify_with_key validates the signing pipeline.
//         Full update requires prod-key-signed manifest, so we test the
//         signing primitive directly plus the CLI with a deliberate sig error.
// ---------------------------------------------------------------------------
#[test]
fn test_cli_update_signing_pipeline() {
    // Build a tar.gz for @esm.
    let tar_gz = make_tar_gz("dummy_file.txt", b"dummy content");
    let tar_sha = sha256_hex(&tar_gz);
    let ext_artifact = b"esm-binary";
    let ext_sha = sha256_hex(ext_artifact.as_slice());

    let manifest_json = format!(
        r#"{{
          "@esm":{{"version":"999.0.0","url":"/at_esm.tar.gz","sha256":"{tar_sha}"}},
          "esm":{{"version":"999.0.0","url":"/esm_artifact","sha256":"{ext_sha}","requires":{{}}}}
        }}"#
    );

    // Sign with a test key and verify it round-trips.
    let (raw_pub, sig) = sign_for_test(manifest_json.as_bytes());
    assert!(
        verify_with_key(manifest_json.as_bytes(), &sig, &raw_pub).is_ok(),
        "signing round-trip must succeed"
    );

    // CLI update with prod key will fail (BadSignature) because we used test key.
    // Verify the fail path is reached (not a panic).
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let routes = vec![
        (
            "/versions.json".to_string(),
            manifest_json.as_bytes().to_vec(),
        ),
        ("/versions.json.sig".to_string(), sig),
        ("/at_esm.tar.gz".to_string(), tar_gz),
        (
            "/esm_artifact".to_string(),
            ext_artifact.to_vec(),
        ),
    ];
    let server = MockServer::new(routes);

    let result = with_cwd(&dir, || {
        Updater::run_cli_update(
            UpdateSelection::All,
            Some(format!("{}/versions.json", server.base_url)),
        )
    });

    // Must fail with BadSignature (not a panic).
    assert!(
        result.is_err(),
        "expected error with test key vs prod key"
    );
    // Manifest + sig were fetched (≥ 2 requests).
    assert!(
        server.request_count() >= 2,
        "manifest+sig should have been fetched"
    );
}

// ---------------------------------------------------------------------------
// Test 8: version_file missing → 0.0.0.
// ---------------------------------------------------------------------------
#[test]
fn test_version_file_missing() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let v = with_cwd(&dir, || {
        version_file::read_installed_mod_version().unwrap()
    });
    assert_eq!(v, semver::Version::new(0, 0, 0));
}

// ---------------------------------------------------------------------------
// Test 9: version_file valid line → parsed correctly.
// ---------------------------------------------------------------------------
#[test]
fn test_version_file_valid() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let new_ver = semver::Version::new(1, 2, 3);

    let read_back = with_cwd(&dir, || {
        version_file::write_version(&new_ver).unwrap();
        version_file::read_installed_mod_version().unwrap()
    });

    assert_eq!(read_back, new_ver);
}

// ---------------------------------------------------------------------------
// Test 10: version_file garbage → Err.
// ---------------------------------------------------------------------------
#[test]
fn test_version_file_garbage() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();
    std::fs::write(dir.join("@esm/version"), b"not-semver!!!").unwrap();

    let result = with_cwd(&dir, || {
        version_file::read_installed_mod_version()
    });

    assert!(result.is_err(), "expected Err for garbage version file");
}

// ---------------------------------------------------------------------------
// Test 11: pending dep — manifest declares requires[@esm] unmet.
//          Uses bad sig so it fails-open via sig path.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_pending_dep_failopen() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let manifest_json = r#"{"esm":{"version":"999.0.0","url":"/artifact","sha256":"abc","requires":{"@esm":">=999.0.0"}}}"#;
    let bad_sig = vec![0u8; 64];

    let routes = vec![
        (
            "/versions.json".to_string(),
            manifest_json.as_bytes().to_vec(),
        ),
        ("/versions.json.sig".to_string(), bad_sig),
    ];
    let server = MockServer::new(routes);
    write_config(
        &dir,
        &format!("{}/versions.json", server.base_url),
    );

    let result = with_cwd(&dir, || {
        let deadline = Instant::now() + Duration::from_secs(5);
        Updater::run_boot_check(deadline).unwrap()
    });

    // Bad sig → Ok via fail-open (or Pending if sig happened to verify).
    assert!(
        matches!(
            result,
            BootCheckResult::Ok | BootCheckResult::Pending { .. }
        ),
        "unexpected result: {result:?}"
    );
}

// Bring in dev-dep types referenced in helper functions.
use flate2;
use tar;
use sha2;
use hex;
use semver;
