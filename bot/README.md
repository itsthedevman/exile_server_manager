# Exile Server Manager (ESM)

<p align="center">
	<a href="https://www.ruby-lang.org/en/">
		<img src="https://img.shields.io/badge/Ruby-v3.2.2-green.svg" alt="ruby version">
	</a>
	<a href="https://www.esmbot.com/releases">
		<img src="https://img.shields.io/badge/ESM-v2.4.0-blue.svg" alt="esm version">
	</a>
</p>

ESM is a Discord Bot that interfaces with Exile servers through an Arma 3 server mod. By integrating with both Discord and Exile servers, players can manage their territories, check server status, and receive XM8 notifications even while offline. Server owners can monitor and manage their servers directly through Discord.

## Links

- [Getting Started Guide](https://esmbot.com/getting_started)
- [Website](https://esmbot.com)
- [Join our Discord](https://esmbot.com/join)
- [Invite ESM](https://esmbot.com/invite)

## Suggestions

ESM was and still is built for the Exile community. A majority of ESM's features started as community suggestions. Join our [Discord](https://esmbot.com/join) and share your ideas in the #suggestions channel.

---

## For Developers

This is the source code for ESM's Discord bot. If you're looking to install ESM for your Exile server, please visit our [Getting Started Guide](https://esmbot.com/getting_started).

### Requirements

- Linux
- Docker & Docker Compose
- Discord application
- Understanding of:
  - Ruby
  - discordrb
  - Active Record
  - RSpec
  - PostgreSQL
  - Redis

### Setup

#### Method 1: Using Nix (Recommended)

```bash
# Install nix and direnv
# Enable flakes in your nix config
direnv allow
```

#### Method 2: Manual Setup

1. Install requirements:

   - Linux
   - Docker & Docker Compose
   - Ruby (recommended to use asdf)

2. Setup environment:

```bash
# Clone and enter directory
git clone [repository-url]
cd esm_bot

# Start required databases
docker compose up -d postgres-db redis-db

# Duplicate .env.example and configure
cp .env.example .env
# Edit .env with your configuration

# Initialize database and dependencies
bin/setup

# Start development
bin/dev
```

### Core Systems

- **Commands**: Modular system with argument parsing, permission handling and validation
- **Connection**: TCP-based encrypted communication with Arma 3 servers
  - Promise-based request/response handling
  - Automatic reconnection
  - Client and server socket abstractions
- **Database**: PostgreSQL with Active Record models
- **Events**: Handles events from Discord and Arma 3 servers

### License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>

ESM is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).
