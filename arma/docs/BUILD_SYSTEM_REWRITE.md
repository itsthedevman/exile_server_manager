# Build System Rewrite Brief

## Goal

A complete reimagination of `src/build/` as clean, idiomatic, modern Rust — not a
patch job. The existing system was written for Linux↔Windows remote builds and has
accumulated architectural debt. Bryan is Linux-only now, so the primary target is
Linux+Docker. The Windows remote path should compile and remain logically correct
but will be gated behind a runtime check and is not expected to work until a Windows
machine is available.

Think of this as a reference implementation: clean structure, good patterns, worth
reading.

---

## What the Build Tool Does (Preserve This Behaviour)

`bin/build` is a developer inner-loop tool. It:

1. Starts a Docker container running an Arma 3 dedicated server
2. Compiles the SQF mod tree (`src/@esm/`) into PBOs using `armake2`
3. Cross-compiles the Rust extensions (`src/esm/`, `src/updater/`) via `cargo build`
4. Deploys everything into `@esm/` inside the container
5. Starts the Arma 3 server
6. Streams the server's RPT log back to the terminal with colour highlighting

CLI flags to preserve (exact names, exact behaviour):

```
--target   linux|windows   build platform (default: linux)
--x32                      build 32-bit extension (default: 64-bit)
--only     mod|extension   build only one component
--full                     force full rebuild
--release                  production build (no development feature flag)
--start-server             deploy and start the server after building
--log-level                passed through to the extension at runtime
--bot-host                 ESM bot URI injected into config.yml
--update                   update the Arma server via steamcmd
--key-file                 path to esm.key, for --release --start-server
```

---

## Existing Code to Keep

### `src/build/common/`

Keep the entire `Command` enum and all protocol types — they are the wire format for
the Windows receiver and must not change. Keep `System::execute` and
`System::execute_remote`. Keep `FileTransfer*`, `PostInit`, `LogLine`, etc.
`NetworkSend` trait stays.

The only addition needed here is a `DockerCommand` or similar that wraps
`docker exec` — or that can just live in `host/`.

### `src/build/receiver/`

Keep entirely. The receiver binary is the Windows remote agent. It is not called
during Linux+Docker builds but must continue to compile. No changes needed.

### `src/build/compiler/`

Keep entirely. The SQF compiler is correct and has no architectural issues.

### Highlights / FileWatcher / String table

Keep `common::HIGHLIGHTS`, `common::WHITESPACE_REGEX`, `FileWatcher`,
`string_table`. These are fine.

---

## What to Rewrite

Everything in `src/build/host/src/` is fair game for a full rewrite.

---

## The Core Architectural Problem

The original system has one `Builder` struct that holds everything and one
`build_steps.rs` full of free functions that mutate it. There is no separation
between:

- **Where** commands run (local, Docker, Windows remote)
- **What** is being built (mod, extension, updater)
- **Whether** it needs rebuilding (change detection)
- **How** the result gets deployed

The rewrite should separate these concerns cleanly.

---

## Proposed Architecture

### 1. `Target` Trait — Abstracts Where Commands Run

```rust
/// Abstracts the machine where build commands execute and files land.
pub trait Target {
    /// Run a shell command and return its stdout.
    fn run(&self, cmd: &str) -> Result<String, BuildError>;

    /// Copy a local file/directory to the target at `dest`.
    fn upload(&self, local: &Path, dest: &Path) -> Result<(), BuildError>;

    /// Copy a file/directory from the target to a local path.
    fn download(&self, remote: &Path, local: &Path) -> Result<(), BuildError>;

    /// Return the build staging path on this target (e.g. `/tmp/esm`).
    fn build_path(&self) -> &Path;

    /// Return the Arma 3 server root on this target.
    fn server_path(&self) -> &Path;

    /// Return the Arma 3 server launch arguments.
    fn server_args(&self) -> &str;
}
```

Two concrete implementations:

**`DockerTarget`** — used when `--target=linux`. Runs `docker exec -t
ESM_ARMA_SERVER /bin/bash -c "<cmd>"` locally. Uses `docker compose cp` for file
transfers. Reads `build_path`, `server_path`, `server_args` from `config.yml` (no
receiver handshake needed).

**`RemoteTarget`** — used when `--target=windows` (or a remote Linux host). Wraps
the existing TCP receiver protocol. Sends `Command::System` over the connection.
Uses `File::transfer` for uploads. Gets `build_path`/`server_path`/`server_args`
from the `PostInit` handshake as today.

Construction:
```rust
fn build_target(args: &Args, config: &Config) -> Result<Box<dyn Target>, BuildError> {
    match args.build_os() {
        BuildOS::Linux  => Ok(Box::new(DockerTarget::new(config)?)),
        BuildOS::Windows => Ok(Box::new(RemoteTarget::connect(config)?)),
    }
}
```

This means every build step function takes `&dyn Target` and never cares whether it
is talking to Docker or a Windows machine.

### 2. `BuildContext` — Replaces the Monolithic `Builder`

```rust
pub struct BuildContext {
    pub args: Args,
    pub config: Config,
    pub target: Box<dyn Target>,
    pub git_path: PathBuf,
    pub local_build_path: PathBuf,   // host-local staging: target/
    pub file_watcher: FileWatcher,
    pub rebuild_mod: bool,
    pub rebuild_extension: bool,
}
```

No TCP server handle, no Redis client, no `remote` sub-struct — those belong in
`RemoteTarget`.

Helper methods stay: `rebuild_mod()`, `rebuild_extension()`, `rebuild_addon()`.

### 3. Build Pipeline — Explicit, Named, Readable

Replace the imperative `Builder::run()` with a declarative list:

```rust
type Step = (&'static str, fn(&mut BuildContext) -> BuildResult);

fn pipeline(ctx: &BuildContext) -> Vec<Step> {
    let mut steps: Vec<Step> = vec![
        ("Detecting rebuild",   detect_rebuild),
        ("Preparing staging",   prepare_staging),
    ];

    if ctx.rebuild_mod() {
        steps.push(("Building mod", build_mod));
    }

    if ctx.rebuild_extension() {
        steps.push(("Building extension",         build_extension));
        steps.push(("Building updater extension", build_updater_extension));
    }

    if ctx.args.start_server() {
        steps.push(("Seeding database",  seed_database));
        steps.push(("Deploying",         deploy));
        steps.push(("Starting server",   start_server));
        steps.push(("Streaming logs",    stream_logs));
    } else if ctx.args.release {
        steps.push(("Copying to release", copy_release));
    }

    steps
}
```

Each step function signature: `fn(&mut BuildContext) -> BuildResult`. The runner
in `main()` iterates the list, prints the step name, and surfaces errors cleanly.

### 4. `detect_rebuild` — Check Build Outputs, Not the Server

Current (wrong): checks `server_path/@esm/*.pbo` for existence.

Correct: check `build_path/@esm/` (the staging area) for expected outputs. If an
expected file is missing, trigger a rebuild.

```rust
fn detect_rebuild(ctx: &mut BuildContext) -> BuildResult {
    let expected_pbos: Vec<String> = ADDONS
        .iter()
        .map(|a| format!("addons/{a}.pbo"))
        .collect();

    let expected_ext = extension_filename(ctx.args.build_arch(), ctx.args.build_os());

    for path in expected_pbos.iter().chain(std::iter::once(&expected_ext)) {
        let full = ctx.target.build_path().join("@esm").join(path);
        if !ctx.target.exists(&full)? {
            ctx.rebuild_mod = true;
            ctx.rebuild_extension = true;
            return Ok(());
        }
    }

    Ok(())
}
```

`Target` gets an `exists(&Path) -> Result<bool>` method. For Docker: `docker exec
test -f <path>`. For Remote: `Command::System` with `test -f` / `Test-Path`.

### 5. `prepare_staging` — The Correct Wipe Strategy

Goal: `build_path/@esm/` is always a **complete, correct** staging area before
`deploy` runs. The server gets a clean copy from staging; rogue files never appear.

```rust
fn prepare_staging(ctx: &mut BuildContext) -> BuildResult {
    let staging = ctx.target.build_path().join("@esm");

    // Populate staging from the currently-deployed server as a baseline.
    // This means partial rebuilds have the full picture even on a fresh container.
    ctx.target.download(&ctx.target.server_path().join("@esm"), &staging)?;

    // Now wipe only what we are about to rebuild, so stale outputs don't linger.
    if ctx.rebuild_mod() {
        ctx.target.run(&format!(
            "rm -rf {staging}/addons {staging}/sql {staging}/optionals \
             {staging}/README.md {staging}/version",
            staging = staging.display()
        ))?;
    }

    if ctx.rebuild_extension() {
        ctx.target.run(&format!(
            "rm -f {staging}/esm*.so {staging}/esm*.dll",
            staging = staging.display()
        ))?;
    }

    ctx.target.run(&format!("mkdir -p {staging}/addons {staging}/log",
        staging = staging.display()))?;

    Ok(())
}
```

### 6. `deploy` — Clean Copy From Staging

```rust
fn deploy(ctx: &mut BuildContext) -> BuildResult {
    let staging = ctx.target.build_path().join("@esm");
    let server  = ctx.target.server_path().join("@esm");

    ctx.target.run(&format!(
        "rm -rf {server} && cp -rf {staging} {server}",
        server  = server.display(),
        staging = staging.display(),
    ))?;

    Ok(())
}
```

Staging is always complete → server is always clean → no rogue files.

### 7. Log Streaming for Docker

Replace the TCP poll loop with a direct `docker exec` tail:

```rust
// DockerTarget::stream_logs
fn stream_logs(&self, log_path: &Path) -> Result<(), BuildError> {
    // Spawns `docker exec -t ESM_ARMA_SERVER tail -F <log_path>` as a child
    // process and reads its stdout line by line, applying HIGHLIGHTS.
}
```

---

## File Layout for the Rewrite

```
src/build/host/src/
├── main.rs           Args (unchanged), ADDONS, constants, pipeline runner
├── context.rs        BuildContext, rebuild_* helpers
├── target/
│   ├── mod.rs        Target trait + build_target() factory
│   ├── docker.rs     DockerTarget
│   └── remote.rs     RemoteTarget (existing TCP receiver logic)
├── steps/
│   ├── mod.rs        (re-exports)
│   ├── detect.rs     detect_rebuild
│   ├── staging.rs    prepare_staging
│   ├── mod_build.rs  build_mod, compile_mod, check_sqf, compile_string_table
│   ├── ext_build.rs  build_extension, build_updater_extension
│   ├── deploy.rs     deploy, copy_release
│   ├── server.rs     seed_database, start_server
│   └── logs.rs       stream_logs
├── builder.rs        print_header, print_build_info (display helpers only)
└── config.rs         Config parsing (unchanged)
```

---

## Implementation Notes

### Windows / RemoteTarget

`RemoteTarget::new()` should return `Err` immediately with a clear message:
```
Windows remote builds require a receiver process. See docs/BUILD_SYSTEM_REWRITE.md.
```
...so the code compiles, `--target=windows` fails fast and clearly, and nothing
is silently broken.

### Error Type

Replace `Box<dyn std::error::Error>` with a proper enum using `thiserror`. Already
used in `updater_lib` — use the same pattern:

```rust
#[derive(Debug, thiserror::Error)]
pub enum BuildError {
    #[error("command failed: {0}")]
    Command(String),
    #[error("file transfer: {0}")]
    Transfer(#[from] std::io::Error),
    #[error("config: {0}")]
    Config(String),
    // ...
}
```

`BuildResult = Result<(), BuildError>` stays.

### `DockerTarget::run(cmd)`

```rust
fn run(&self, cmd: &str) -> Result<String, BuildError> {
    System::new()
        .command("docker")
        .arguments(&["exec", "-t", ARMA_CONTAINER, "/bin/bash", "-c", cmd])
        .execute(None)
        .map_err(BuildError::Command)
}
```

That's it. No TCP, no serialization, no receiver needed.

### Incremental Builds (FileWatcher Integration)

`rebuild_addon(name)` stays as-is. The watcher correctly detects source changes.
`detect_rebuild` fills in the "does this output even exist" case (fresh container,
first build). Together they cover all scenarios:

| Scenario | detect_rebuild | file_watcher | Result |
|----------|----------------|--------------|--------|
| First build / clean container | misses → triggers full | — | Full build |
| Source file changed | outputs present | detects change | Partial rebuild |
| No changes | outputs present | no changes | No rebuild |
| `--full` | skipped | skipped | Full rebuild (flag override) |

---

## What "Modern Rust" Looks Like Here

- Traits for polymorphism (`Target`), not `match target_os` strings everywhere
- `thiserror` for error types, `?` for propagation — no string errors
- Small focused functions — each step is ~20 lines, not ~100
- No `lazy_static!` in `host/` (use `OnceLock` or `std::sync::LazyLock` if needed)
- Owned types, no unnecessary `Arc<RwLock<>>` in the happy path
- `Box<dyn Target>` is the one intentional dynamic dispatch — it's the right call
  for making `DockerTarget` and `RemoteTarget` interchangeable
- All the `System::execute` shell-building machinery stays in `common/` and is
  reused — it's good, just needs to be called more cleanly
