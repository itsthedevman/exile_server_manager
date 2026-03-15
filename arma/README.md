# Exile Server Manager (ESM) - Arma 3 Mod

> **Note**: This is the source code repository for ESM's Arma 3 mod. If you're looking to install ESM for your Exile server, please visit [esmbot.com/getting_started](https://esmbot.com/getting_started).

This repository contains the Rust extension and Arma 3 server mod that enables communication between Exile servers and Discord. The Rust extension acts as a bridge, handling database operations and TCP communication with ESM Bot, while the server mod provides the in-game functionality through SQF.

## Links

- [Official Website](https://esmbot.com)
- [Installation Guide](https://esmbot.com/getting_started)
- [Discord](https://esmbot.com/join)

## Components

- **Rust Extension**: Handles TCP communication, database operations, and request routing
- **Arma 3 Mod**: Provides SQF functions for in-game operations and Exile integration
- **Build System**: Cross-platform tooling for development and deployment

### Requirements

- Rust (stable)
- Docker & Docker Compose
- Git

For Windows development, you'll also need to install these Rust targets:

```bash
rustup install stable-x86_64-pc-windows-gnu
rustup install stable-i686-pc-windows-gnu
```

### Setup

#### Method 1: Using Nix (Recommended)

```bash
# Install nix and direnv
# Enable flakes in your nix config
direnv allow
```

#### Method 2: Manual Setup

1. **Clone the repository**

   ```bash
   git clone git@github.com:itsthedevman/esm_arma
   cd esm_arma
   ```

2. **Start Docker services and verify MySQL is running**

   ```bash
   docker compose up -d
   ```

   Wait for the MySQL container to fully initialize before proceeding.

   > **Firewall**: Port `54321` must be allowed through your firewall. The build host (`src/build/host`) listens on this port, and the build receiver (`src/build/receiver`) connects to it to receive build instructions during the build process.

3. **Create the Exile database**

   ```bash
   bin/db_init
   ```

4. **Install SteamCMD and Arma 3 server**

   ```bash
   bin/build --update
   ```

   This ensures SteamCMD is working and downloads/updates the Arma 3 dedicated server.

5. **Configure ESM**

   ```bash
   cp config.example.yml config.yml
   ```

   Edit `config.yml` and fill in your configuration values.

6. **Install Exile mod**
   - Download the Exile mod from the official source
   - Copy the contents of `@Exile/addons` into `tools/server/@exile/addons`

7. **Start the development environment**
   ```bash
   bin/dev
   ```

### Common Commands

```bash
bin/build    # Build everything
bin/dev      # Start development environment
```

### Source Layout

```
src/
├── build/            # Build system
├── @esm/            # Arma 3 Server mod (SQF/config)
└── esm/             # Rust extension
```

## License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>

ESM is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).
