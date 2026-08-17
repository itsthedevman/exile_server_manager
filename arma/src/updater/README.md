# ESM Updater

Keeps an Arma 3 server's ESM install current without the operator having to notice a release happened.

A server checks a signed manifest once while it boots and swaps its extension binary if a newer one is offered.
Everything else installs through the CLI with the server stopped.

## Why this is a separate crate

The extension can't update itself.
By the time `exile_server_manager` runs, Arma has already mapped `esm_x64.so` into the process and the file is locked
against replacement on Windows and pointless to replace on Linux.

`esm_updater` is a second cdylib loaded by its own addon during `preInit`, before ESM's `preInit` runs.
In that window the extension is still just a file on disk.
That load-order gap is the whole reason for the split, and it is why the boot path installs the extension and nothing
else: PBOs are already in use by then, and the updater components are the ones doing the swapping.

## Layout

| Path                   | What it is                                                                                       |
| ------------------------| --------------------------------------------------------------------------------------------------|
| `lib/`                 | Fetch, verify, download, swap, and version bookkeeping. Every other crate here is a thin caller. |
| `extension/`           | The `preInit` cdylib. One command, `check_update`.                                               |
| `cli/`                 | `esm_updater`, the operator-facing binary.                                                       |
| `lib/keys/updater.pub` | The manifest verification key, compiled into every build.                                        |

The mod-side half lives at `src/@esm/addons/esm_updater/`, whose `fn_preInit.sqf` is what calls `check_update`.

## Trust model

`versions.json` is signed with an ed25519 key, and the detached signature sits beside it at `versions.json.sig`.
The public half is compiled into every build from `lib/keys/updater.pub`.
The manifest carries a SHA-256 per artifact.

The signature authorises the manifest, and the manifest authorises the binaries.
Both halves are load-bearing: a per-artifact checksum is not a substitute for the signature, because the manifest is
what declares the checksum in the first place.

## Boot path

`check_update` runs inside Arma's startup with a shared network deadline across the manifest fetch and the download,
default 800ms.

It fails open on everything.
A dead host, a 404, a bad signature, a checksum mismatch, or a blown deadline all leave the server booting normally on
the version it already had.
An update that can't be verified is worth less than a server that starts.

Failures land in `@esm/log/updater.log`, not the RPT.

## CLI

```
esm_updater check      # report what is available, install nothing
esm_updater update [all|extension|mod|updater]
esm_updater install    # alias for `update all`
esm_updater version
```

`check` exits `0` when everything is current, `2` when updates are available, and `1` on error, so it drops into a
cron job or a pre-restart script without parsing output.

`--manifest-url` points any subcommand at a different manifest, which is how staging gets tested.
`--server-root` changes directory first, since every path the updater touches is relative to the server root.

The CLI never replaces itself.
When the manifest offers a newer CLI than the running one it prints a warning and carries on, because swapping the
binary that is mid-update is the operator's call.

## Configuration

Read from `@esm/config.yml`.
A missing file, a missing key, or a parse error all fall back to defaults, so a server with no config still updates.

| Key | Default | |
|-----|---------|--|
| `updater_enabled` | `true` | `false` returns before any network request is made. |
| `updater_url` | `https://esmbot.com/updates/arma/versions.json` | The `.sig` is fetched from the same path plus `.sig`. |
| `updater_timeout_ms` | `800` | Shared deadline across the whole boot-check network path. |
| `log_path` | `@esm/log/updater.log` | |

`updater_enabled` is the one an owner sets from the website's server configuration page.

## Installed versions

`@esm/installed_versions.yml` records what is on disk, keyed exactly as the manifest is:

```yaml
esm: 2.1.0
"@esm": 2.1.0
extension_updater: 0.1.0
mod_updater: 0.1.0
```

The updater compiled into the boot path can't ask the extension its version, because Arma has not loaded it yet, and
its own `CARGO_PKG_VERSION` describes the wrong crate.
This file is the answer to both.

`bin/package` seeds it, so a fresh install doesn't immediately re-download what it shipped with.

## Manifest

```json
{
  "esm": {
    "version": "2.1.0",
    "artifacts": {
      "linux-x64":   { "url": "https://esmbot.com/updates/arma/v2.1.0/esm_x64.so",  "sha256": "..." },
      "windows-x64": { "url": "https://esmbot.com/updates/arma/v2.1.0/esm_x64.dll", "sha256": "..." }
    },
    "requires": { "@esm": ">=2.1.0" }
  },
  "@esm": {
    "version": "2.1.0",
    "artifacts": {
      "any": { "url": "https://esmbot.com/updates/arma/v2.1.0/@esm-addons.tar.gz", "sha256": "..." }
    }
  }
}
```

Top-level keys are `esm`, `@esm`, `extension_updater`, `mod_updater`, and `updater_cli`.
An absent key offers nothing for that component.

Artifacts are keyed by platform (`linux-x64`, `linux-x86`, `windows-x64`, `windows-x86`, or `any` for the components
that ship one file for everyone).
One signed document covers all four platforms so that a server verifies exactly one manifest regardless of what it
runs.
A platform missing from the map is simply not offered this release.

URLs must be absolute.
Nothing resolves a relative path, and a relative URL fails at download time rather than at parse time.

`requires` defers an update until its dependency is satisfied, which is what keeps an extension from landing on a mod
bundle too old to work with it.

`updater_cli` is advisory only.
Nothing installs it, and it exists so a stale CLI can be reported rather than silently carried.

## Publishing a release

The manifest is generated and signed on a workstation, never by the website, and deliberately not wired into
`bin/release`.
Keeping the two apart means a version can be retargeted, rolled back, or staged to one server by publishing a new
manifest, without building or tagging anything.

```sh
bin/package                          # build and stage target/build_release
bin/manifest --key ~/updater.key     # hash, describe, sign
shred -u ~/updater.key
bin/upload                           # publish
```

Artifact URLs are the base URL plus a bare filename, so the published layout is flat.
A file that keeps its packaged subdirectory is a file the manifest does not point at.

**The artifacts go up before the manifest that describes them.**
A manifest published ahead of its files points every server at URLs that 404, and while the boot path fails open on
that, it is a self-inflicted outage of the feature.

Don't commit `versions.json` into `website/public/`.
That turns publishing into a commit plus a deploy, which is heavier than cutting a release and gives back the
flexibility this shape exists to buy.

nginx serves `/updates/` from the website host, configured in the `infrastructure` repo's `app_esm_website` role.
Each location pins its own `try_files ... =404`, so a missing file 404s instead of falling through to Rails and
answering a program with an HTML error page.

## Tests

The integration tests are gated behind a feature, so `--workspace` alone silently skips all of them:

```sh
cargo test -p updater_lib --features testing
```

The gate exists because the public key is `include_bytes!`'d at compile time.
Without a way to override it, no test can produce a manifest the verifier accepts, and every boot-path test fails open
at the signature check without reaching the logic it meant to exercise.
`testing` opens a key override so the suite signs with its own keypair and runs the real verify path.
