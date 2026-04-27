# exile_server_manager

ESM monorepo. All four components live here with their full git history.

- `bot/` — ESM Discord bot (Ruby)
- `core/` — shared Ruby gem (`esm_ruby_core`)
- `website/` — ESM Rails website (Ruby/Node)
- `arma/` — ESM Arma extension (Rust)

Run `nix develop` from the repository root to enter the unified dev shell, which provides Ruby, Node, Rust, and all database tooling. To load the shell automatically when entering a subdir, `cd` into the subdir — each subdir's `.envrc` delegates to the root flake via `use flake ..`.
