//! Integration tests for updater_lib.
//!
//! Each test that changes `current_dir` acquires `CWD_LOCK` to prevent
//! parallel tests from interfering with each other (cwd is process-global).
//! The same lock covers the verification-key override, which is likewise
//! process-global.

use std::net::TcpListener;
use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use semver::Version;
use tempfile::TempDir;
use updater_lib::installed_versions;
use updater_lib::signing::{sign_for_test, test_key, verify_with_key};
use updater_lib::{BootCheckResult, Component, UpdateSelection, Updater};

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
        Self::on_port(free_port(), routes)
    }

    /// Same, on a port chosen by the caller.
    ///
    /// Artifact URLs in a manifest are absolute, and the manifest is signed, so its contents have to be final before
    /// the server exists. Reserving the port first is what breaks that circle.
    fn on_port(port: u16, routes: Vec<(String, Vec<u8>)>) -> Self {
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
// Helper: stand up a signed-manifest server and run the boot check against it.
//
// Signing with an ephemeral key and installing it as the verification key is
// what lets a test get past the signature check at all. Without it the
// production key is unreachable, every manifest a test can build reads as
// unsigned, and nothing below the signature check is ever reached.
//
// Returns the boot result plus the server so request counts can be asserted.
// ---------------------------------------------------------------------------
fn boot_check_against(
    dir: &std::path::Path,
    build_manifest: impl Fn(&str) -> String,
    artifacts: Vec<(String, Vec<u8>)>,
) -> (BootCheckResult, MockServer) {
    let port = free_port();
    let base_url = format!("http://127.0.0.1:{port}");
    let manifest = build_manifest(&base_url);
    let (raw_pub, sig) = sign_for_test(manifest.as_bytes());

    let mut routes = vec![
        ("/versions.json".to_string(), manifest.as_bytes().to_vec()),
        ("/versions.json.sig".to_string(), sig),
    ];
    routes.extend(artifacts);

    let server = MockServer::on_port(port, routes);
    write_config(dir, &format!("{}/versions.json", server.base_url));

    let result = with_cwd(dir, || {
        test_key::set(&raw_pub);
        let deadline = Instant::now() + Duration::from_secs(5);
        let out = Updater::run_boot_check(deadline).unwrap();
        test_key::clear();
        out
    });

    (result, server)
}

// ---------------------------------------------------------------------------
// Test: the installed version is what gets compared, not the updater's own.
//
// This is the regression test for the bug where `env!("CARGO_PKG_VERSION")`
// resolved to updater_lib's 0.1.0, so any manifest version compared as newer
// and every boot re-downloaded and re-swapped the extension forever.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_skips_when_installed_version_is_current() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let sentinel = dir.join("@esm/esm_x64.so");
    std::fs::write(&sentinel, b"installed-extension").unwrap();

    // Record 2.0.0 as installed, then offer exactly 2.0.0.
    with_cwd(&dir, || {
        installed_versions::record(Component::Esm, &Version::new(2, 0, 0)).unwrap()
    });

    let artifact = b"replacement-extension".to_vec();
    let sha = sha256_hex(&artifact);

    let (result, server) = boot_check_against(
        &dir,
        |base| {
            format!(
                r#"{{"esm":{{"version":"2.0.0","url":"{base}/artifact","sha256":"{sha}","requires":{{}}}}}}"#
            )
        },
        vec![("/artifact".into(), artifact)],
    );

    assert!(
        matches!(result, BootCheckResult::Ok),
        "an already-current extension must not update, got {result:?}"
    );
    assert!(
        server.request_count() <= 2,
        "artifact must not be fetched when current; requests={}",
        server.request_count()
    );
    assert_eq!(
        std::fs::read(&sentinel).unwrap(),
        b"installed-extension",
        "the installed extension must be left alone"
    );
}

// ---------------------------------------------------------------------------
// Test: a genuinely newer version installs, and the new version is recorded.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_installs_newer_extension_and_records_it() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();
    std::fs::write(dir.join("@esm/esm_x64.so"), b"old-extension").unwrap();

    with_cwd(&dir, || {
        installed_versions::record(Component::Esm, &Version::new(1, 0, 0)).unwrap()
    });

    let artifact = b"new-extension-bytes".to_vec();
    let sha = sha256_hex(&artifact);

    let (result, _server) = boot_check_against(
        &dir,
        |base| {
            format!(
                r#"{{"esm":{{"version":"2.0.0","url":"{base}/artifact","sha256":"{sha}","requires":{{}}}}}}"#
            )
        },
        vec![("/artifact".into(), artifact.clone())],
    );

    match result {
        BootCheckResult::Updated { component, version } => {
            assert_eq!(component, "esm");
            assert_eq!(version, "2.0.0");
        }
        other => panic!("expected Updated, got {other:?}"),
    }

    assert_eq!(
        std::fs::read(dir.join("@esm/esm_x64.so")).unwrap(),
        artifact,
        "the new artifact must be in place"
    );

    let recorded = with_cwd(&dir, || installed_versions::load().unwrap());
    assert_eq!(
        recorded.version_of(Component::Esm),
        Version::new(2, 0, 0),
        "the installed version must be recorded after a swap"
    );
}

// ---------------------------------------------------------------------------
// Test: installing is idempotent across boots.
//
// The original bug did not present as a wrong version number, it presented as
// a server that re-downloaded the same extension on every single boot. This
// asserts the property that was actually broken.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_is_a_noop_on_the_second_boot() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();
    std::fs::write(dir.join("@esm/esm_x64.so"), b"old-extension").unwrap();

    let artifact = b"new-extension-bytes".to_vec();
    let sha = sha256_hex(&artifact);
    let manifest_for = |base: &str| {
        format!(
            r#"{{"esm":{{"version":"2.0.0","url":"{base}/artifact","sha256":"{sha}","requires":{{}}}}}}"#
        )
    };

    let (first, _) = boot_check_against(
        &dir,
        &manifest_for,
        vec![("/artifact".into(), artifact.clone())],
    );
    assert!(
        matches!(first, BootCheckResult::Updated { .. }),
        "first boot should install, got {first:?}"
    );

    let (second, server) = boot_check_against(
        &dir,
        &manifest_for,
        vec![("/artifact".into(), artifact)],
    );
    assert!(
        matches!(second, BootCheckResult::Ok),
        "second boot must be a no-op, got {second:?}"
    );
    assert!(
        server.request_count() <= 2,
        "second boot must not re-download; requests={}",
        server.request_count()
    );
}

// ---------------------------------------------------------------------------
// Test: an unmet dependency defers the update rather than applying it.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_defers_on_unmet_dependency() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let (result, server) = boot_check_against(
        &dir,
        |base| {
            format!(
                r#"{{"esm":{{"version":"2.0.0","url":"{base}/artifact","sha256":"abc","requires":{{"@esm":">=9.0.0"}}}}}}"#
            )
        },
        vec![],
    );

    match result {
        BootCheckResult::Pending { component, reason } => {
            assert_eq!(component, "esm");
            assert!(reason.contains("@esm"), "reason should name the dep: {reason}");
        }
        other => panic!("expected Pending, got {other:?}"),
    }
    assert!(
        server.request_count() <= 2,
        "a deferred update must not download; requests={}",
        server.request_count()
    );
}

// ---------------------------------------------------------------------------
// Test: `check` reports without touching anything.
// ---------------------------------------------------------------------------
#[test]
fn test_run_check_reports_without_installing() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let sentinel = dir.join("@esm/esm_x64.so");
    std::fs::write(&sentinel, b"installed-extension").unwrap();

    let artifact = b"newer-extension".to_vec();
    let manifest = format!(
        r#"{{"esm":{{"version":"3.0.0","url":"/artifact","sha256":"{}","requires":{{}}}}}}"#,
        sha256_hex(&artifact)
    );

    let (raw_pub, sig) = sign_for_test(manifest.as_bytes());
    let server = MockServer::new(vec![
        ("/versions.json".to_string(), manifest.as_bytes().to_vec()),
        ("/versions.json.sig".to_string(), sig),
        ("/artifact".to_string(), artifact),
    ]);

    let url = format!("{}/versions.json", server.base_url);
    let available = with_cwd(&dir, || {
        test_key::set(&raw_pub);
        let out = Updater::run_check(Some(url)).unwrap();
        test_key::clear();
        out
    });

    assert_eq!(available.len(), 1, "expected one available update: {available:?}");
    assert_eq!(available[0].name, "esm");
    assert_eq!(available[0].installed, Version::new(0, 0, 0));
    assert_eq!(available[0].available, Version::new(3, 0, 0));
    assert!(available[0].blocked_by.is_none());

    assert_eq!(
        std::fs::read(&sentinel).unwrap(),
        b"installed-extension",
        "check must not modify the installed extension"
    );
    assert!(
        server.request_count() <= 2,
        "check must not download artifacts; requests={}",
        server.request_count()
    );
}

// ---------------------------------------------------------------------------
// Test: `check` honours --manifest-url and surfaces a blocked update.
// ---------------------------------------------------------------------------
#[test]
fn test_run_check_reports_blocked_updates() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let manifest = r#"{"esm":{"version":"3.0.0","url":"/artifact","sha256":"abc","requires":{"@esm":">=9.0.0"}}}"#;

    let (raw_pub, sig) = sign_for_test(manifest.as_bytes());
    let server = MockServer::new(vec![
        ("/versions.json".to_string(), manifest.as_bytes().to_vec()),
        ("/versions.json.sig".to_string(), sig),
    ]);

    // Deliberately not written into config.yml — this proves the override is used.
    let url = format!("{}/versions.json", server.base_url);
    let available = with_cwd(&dir, || {
        test_key::set(&raw_pub);
        let out = Updater::run_check(Some(url)).unwrap();
        test_key::clear();
        out
    });

    assert_eq!(available.len(), 1, "expected one entry: {available:?}");
    assert_eq!(
        available[0].blocked_by.as_deref(),
        Some("@esm >=9.0.0"),
        "the unmet requirement should be reported"
    );
}

// ---------------------------------------------------------------------------
// Test: nothing newer on offer means nothing reported.
// ---------------------------------------------------------------------------
#[test]
fn test_run_check_is_empty_when_current() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    with_cwd(&dir, || {
        installed_versions::record(Component::Esm, &Version::new(5, 0, 0)).unwrap()
    });

    let manifest = r#"{"esm":{"version":"5.0.0","url":"/artifact","sha256":"abc","requires":{}}}"#;
    let (raw_pub, sig) = sign_for_test(manifest.as_bytes());
    let server = MockServer::new(vec![
        ("/versions.json".to_string(), manifest.as_bytes().to_vec()),
        ("/versions.json.sig".to_string(), sig),
    ]);

    let url = format!("{}/versions.json", server.base_url);
    let available = with_cwd(&dir, || {
        test_key::set(&raw_pub);
        let out = Updater::run_check(Some(url)).unwrap();
        test_key::clear();
        out
    });

    assert!(available.is_empty(), "expected nothing available: {available:?}");
}

// ---------------------------------------------------------------------------
// Test: signing round-trip — sign_for_test + verify_with_key.
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
// Test: boot check disabled → Disabled, 0 HTTP requests.
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
// Test: boot check deadline already past → Ok in < 100ms.
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
// Test: a correctly signed manifest whose artifact fails its checksum must
// leave the installed extension alone.
//
// Previously this test could not reach the download at all — it stopped at the
// signature check, so it proved nothing about checksum handling.
// ---------------------------------------------------------------------------
#[test]
fn test_boot_check_sha256_mismatch_leaves_extension_untouched() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let sentinel = dir.join("@esm/esm_x64.so");
    std::fs::write(&sentinel, b"original-sentinel").unwrap();

    let wrong_sha =
        "0000000000000000000000000000000000000000000000000000000000000000";

    let (result, _server) = boot_check_against(
        &dir,
        |base| {
            format!(
                r#"{{"esm":{{"version":"2.0.0","url":"{base}/artifact","sha256":"{wrong_sha}","requires":{{}}}}}}"#
            )
        },
        vec![("/artifact".into(), b"data-that-does-not-match".to_vec())],
    );

    assert!(
        matches!(result, BootCheckResult::Ok),
        "expected Ok (fail-open on checksum mismatch), got {result:?}"
    );
    assert_eq!(
        std::fs::read(&sentinel).unwrap(),
        b"original-sentinel",
        "sentinel must be unchanged"
    );

    let recorded = with_cwd(&dir, || installed_versions::load().unwrap());
    assert_eq!(
        recorded.version_of(Component::Esm),
        Version::new(0, 0, 0),
        "a failed install must not record a version"
    );
}

// ---------------------------------------------------------------------------
// Test: bad signature → Ok, artifact endpoint never hit.
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
// Test: the production key rejects a manifest signed with anything else.
//
// The one test that deliberately does NOT install a key override, so it
// exercises the key that actually ships.
// ---------------------------------------------------------------------------
#[test]
fn test_cli_update_rejects_a_manifest_not_signed_by_the_production_key() {
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

    let (raw_pub, sig) = sign_for_test(manifest_json.as_bytes());
    assert!(
        verify_with_key(manifest_json.as_bytes(), &sig, &raw_pub).is_ok(),
        "signing round-trip must succeed"
    );

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
        ("/esm_artifact".to_string(), ext_artifact.to_vec()),
    ];
    let server = MockServer::new(routes);

    let result = with_cwd(&dir, || {
        Updater::run_cli_update(
            UpdateSelection::All,
            Some(format!("{}/versions.json", server.base_url)),
        )
    });

    assert!(
        result.is_err(),
        "a manifest signed with a test key must be rejected by the production key"
    );
    assert!(
        server.request_count() >= 2,
        "manifest+sig should have been fetched"
    );
}

// ---------------------------------------------------------------------------
// Test: no record on disk → every component reads as 0.0.0.
// ---------------------------------------------------------------------------
#[test]
fn test_installed_versions_missing_file() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let versions = with_cwd(&dir, || installed_versions::load().unwrap());

    for component in Component::ALL {
        assert_eq!(
            versions.version_of(component),
            Version::new(0, 0, 0),
            "{} should default to 0.0.0",
            component.key()
        );
    }
}

// ---------------------------------------------------------------------------
// Test: recording one component preserves the others.
// ---------------------------------------------------------------------------
#[test]
fn test_installed_versions_record_preserves_other_components() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let versions = with_cwd(&dir, || {
        installed_versions::record(Component::Esm, &Version::new(1, 2, 3)).unwrap();
        installed_versions::record(Component::EsmMod, &Version::new(4, 5, 6)).unwrap();
        installed_versions::record(Component::ModUpdater, &Version::new(7, 8, 9)).unwrap();
        installed_versions::load().unwrap()
    });

    assert_eq!(versions.version_of(Component::Esm), Version::new(1, 2, 3));
    assert_eq!(versions.version_of(Component::EsmMod), Version::new(4, 5, 6));
    assert_eq!(versions.version_of(Component::ModUpdater), Version::new(7, 8, 9));
    assert_eq!(
        versions.version_of(Component::ExtensionUpdater),
        Version::new(0, 0, 0),
        "an untouched component stays unrecorded"
    );
}

// ---------------------------------------------------------------------------
// Test: a corrupt record is an error, not a silent "nothing installed".
//
// Treating garbage as 0.0.0 would quietly reinstall every component.
// ---------------------------------------------------------------------------
#[test]
fn test_installed_versions_corrupt_file_errors() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();
    std::fs::write(
        dir.join("@esm/installed_versions.yml"),
        b"esm: not-a-version!!!\n",
    )
    .unwrap();

    let result = with_cwd(&dir, installed_versions::load);

    assert!(result.is_err(), "expected Err for a corrupt record");
}

// ---------------------------------------------------------------------------
// Test: the file the updater writes is readable by the updater.
// ---------------------------------------------------------------------------
#[test]
fn test_installed_versions_roundtrips_through_disk() {
    let tmpdir = TempDir::new().unwrap();
    let dir = tmpdir.path().to_path_buf();
    std::fs::create_dir_all(dir.join("@esm")).unwrap();

    let (contents, versions) = with_cwd(&dir, || {
        installed_versions::record(Component::EsmMod, &Version::new(2, 1, 0)).unwrap();
        let contents =
            std::fs::read_to_string("@esm/installed_versions.yml").unwrap();
        (contents, installed_versions::load().unwrap())
    });

    assert_eq!(versions.version_of(Component::EsmMod), Version::new(2, 1, 0));
    assert!(
        contents.starts_with('#'),
        "the record should explain itself to whoever opens it:\n{contents}"
    );
}

// Bring in dev-dep types referenced in helper functions.
use flate2;
use hex;
use sha2;
use tar;
