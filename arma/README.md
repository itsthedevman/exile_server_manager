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

### Setup

#### Method 1: Using Nix (Recommended)
```bash
# Install nix and direnv
# Enable flakes in your nix config
direnv allow
```

#### Method 2: Manual Setup
```bash
# Clone the repository
git clone [repository-url]
cd esm_arma

# Start required services
docker compose up -d

# Start development environment
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
