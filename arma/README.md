# Exile Server Manager - Arma 3 Server mod and extension
This repository source code contains the following:
- `@esm` - The Arma 3 Server mod, written in SQF/A3 Config
- `build` - The custom build tool for this repository, written in Rust
- `esm` - The Arma 3 Server extension, written in Rust
- `message` - The network message data structure for communicating between the bot, the extension, and the mod; written in Rust

# Beyond here lies WIPs

Powershell as admin:
    Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted;

Windows requires (until I create a windows container):
    - Rust
