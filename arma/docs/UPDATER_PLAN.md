# ESM Auto-Updater Implementation Plan

## Overview

Create an auto-updater system with two outputs:
1. **`esm_updater.dll/so`** - Arma extension that updates `esm_arma.dll/so` before Arma loads it
2. **`esm_updater` CLI** - Standalone binary that updates addons, extension, and itself

## Architecture

```
src/updater/
├── lib/          # Shared library (updater_lib) - core logic
├── extension/    # Arma extension (esm_updater cdylib) - thin wrapper
└── cli/          # CLI binary (esm_updater) - thin wrapper
```

## Key Design Decisions

- **HTTP Client**: `ureq` (synchronous, small footprint, perfect for blocking arma-rs)
- **Config**: Add `updater_url` to existing `@esm/config.yml` with hardcoded default
- **Failure Strategy**: Download to temp, only replace on success, keep original intact on any error
- **Extension Behavior**: Never block Arma startup - log errors and return "ok"
- **CLI Self-Update**: Supported (extension only logs notice if updater has update)

## Files to Create

### 1. Workspace Updates
- **`Cargo.toml`** - Add workspace members: `src/updater/lib`, `src/updater/extension`, `src/updater/cli`

### 2. Shared Library (`src/updater/lib/`)
- `Cargo.toml` - Dependencies: ureq, serde, serde_yaml, serde_json, semver, flate2, sha2, log
- `src/lib.rs` - Re-exports
- `src/config.rs` - Load updater settings from @esm/config.yml with defaults
- `src/error.rs` - UpdateError enum
- `src/manifest.rs` - VersionManifest, ComponentVersion structs (JSON response types)
- `src/version.rs` - Semantic version comparison
- `src/http.rs` - ureq wrapper for fetching manifest and downloading files
- `src/download.rs` - Download, verify checksum, extract gzip
- `src/update.rs` - Core update orchestration (Updater struct)

### 3. Arma Extension (`src/updater/extension/`)
- `Cargo.toml` - crate-type: cdylib, name: esm_updater
- `src/lib.rs` - arma-rs init, logging setup, register `check_update` command
- `src/endpoints/mod.rs` - Endpoint registration
- `src/endpoints/check_update.rs` - Blocking command: returns "ok" | "updated:X.Y.Z"

### 4. CLI Binary (`src/updater/cli/`)
- `Cargo.toml` - bin name: esm_updater, deps: clap
- `src/main.rs` - Subcommands: check, update, version

## Config Addition

Add to `@esm/config.yml` (with defaults if missing):
```yaml
updater_url: "https://updates.esmbot.com/versions.json"
```

Default function in config.rs:
```rust
fn default_updater_url() -> String {
    "https://updates.esmbot.com/versions.json".into()
}
```

## Version Manifest JSON Structure

```json
{
  "@esm": { "version": "2.0.1", "release_date": "2024-01-01", "changes": "...", "url": "https://...", "sha256": "..." },
  "esm": { "version": "2.0.1", "release_date": "2024-01-01", "changes": "...", "url": "https://...", "sha256": "..." },
  "extension_updater": { "version": "1.0.0", ... },
  "mod_updater": { "version": "1.0.0", ... }
}
```

## Extension Update Flow

1. Load config (use defaults if missing)
2. HTTP GET `updater_url` (5s timeout) - bail on error
3. Parse JSON manifest - bail on error
4. Compare semver: `current` vs `manifest.esm.version`
5. If updater itself has update - log notice only
6. If esm needs update:
   - Download to `@esm/temp/esm_arma.dll.gz`
   - Verify SHA256 (if provided)
   - Extract gzip
   - Rename current to `.backup`
   - Move new file into place
   - On failure: restore backup
7. Return "ok" or "updated:X.Y.Z"

## CLI Update Flow

```
esm_updater update [--component addon|extension|cli]
```

1. Fetch manifest (30s timeout)
2. Update @esm addons (download tar.gz, extract, backup, replace)
3. Update esm extension (same as extension flow)
4. Self-update CLI binary (platform-specific replacement)

## File Naming

| Component | Windows | Linux |
|-----------|---------|-------|
| ESM Extension | esm_arma.dll / esm_arma_x64.dll | esm_arma.so / esm_arma_x64.so |
| Updater Extension | esm_updater.dll / esm_updater_x64.dll | esm_updater.so / esm_updater_x64.so |
| CLI Tool | esm_updater.exe | esm_updater |
| Backup | *.backup | *.backup |

## Directory Structure (Runtime)

```
@esm/
├── config.yml
├── log/esm.log
├── temp/                    # Created during update
├── esm_arma.dll/so
├── esm_arma.dll.backup      # During update only
├── esm_updater.dll/so
└── esm_updater(.exe)
```

## Implementation Order

1. Create `src/updater/lib/` with core logic
2. Create `src/updater/extension/` with arma-rs integration
3. Create `src/updater/cli/` with clap CLI
4. Add config fields to `src/esm/src/config.rs`
5. Update root `Cargo.toml` workspace members
6. Test extension with mock server
7. Test CLI on both Windows and Linux

## Critical Files to Reference

- `src/esm/src/config.rs` - Config pattern with serde defaults
- `src/esm/src/lib.rs` - Extension init pattern with lazy_static and logging
- `src/esm/src/endpoints/mod.rs` - Command registration pattern
- `Cargo.toml` - Workspace structure
