<p align="center">
  <img src="./esm.svg" alt="ESM Logo" width="100" height="100">
</p>
<h1 align="center">Exile Server Manager (ESM)</h1>

> **Note**: This repo was renamed from `esm_bot` to `exile_server_manager` on
> 12026-05-17. GitHub redirects old links, but please update bookmarks and
> remotes when you get a chance.

ESM connects Discord communities to their Exile (Arma 3) servers. Players manage
territories, check server status, and receive XM8 notifications even when
they're not in-game. Server owners use Discord and a web dashboard to configure
commands, mods, rewards, and notifications, and to monitor their servers.

---

## Using ESM

To install ESM on your server, follow the [Getting Started
guide](https://esmbot.com/getting_started). This repo is the source code.

### Links

- [Website](https://esmbot.com)
- [Getting Started](https://esmbot.com/getting_started)
- [Discord](https://esmbot.com/join)
- [Invite ESM to your server](https://esmbot.com/invite)

### Suggestions

ESM is built for the Exile community, and most features started as community
suggestions. Share yours in the `#suggestions` channel on
[our Discord](https://esmbot.com/join).

---

## How ESM works

### The pieces

| Subdirectory           | Component                                                | Stack           |
| ---------------------- | -------------------------------------------------------- | --------------- |
| [`service/`](service/) | Discord bot: handles commands, events, and notifications | Ruby            |
| [`core/`](core/)       | Shared Ruby library with models and business logic       | Ruby            |
| [`website/`](website/) | Web dashboard at [esmbot.com](https://esmbot.com)        | Rails + Hotwire |
| [`arma/`](arma/)       | Arma 3 server mod and native extension                   | Rust + SQF      |

### How they fit together

The **service** is the Discord-facing process. It receives slash commands and
events from Discord, talks to Arma 3 servers over an encrypted TCP connection,
and persists state to PostgreSQL.

The **arma** component lives on the Arma 3 server. The Rust extension handles
the TCP connection back to the service and Exile database operations, while the
SQF mod provides the in-game functions players trigger.

The **website** is the configuration and management surface for server owners
and players. It talks to the service over local HTTP, and uses Discord OAuth
for user login.

The **core** library is shared Ruby code (models, business logic, helpers)
loaded directly from `core/` by both the service and the website at boot.

```
   Discord  ◄──────►  service  ◄──HTTP──►  website  ◄──HTTPS──  Browser
                         │
                         │ encrypted TCP
                         ▼
                        arma  (Rust extension + SQF mod)
                         │
                         ▼
                  Arma 3 server + Exile MySQL
```

### Where the code lives

```
.
├── service/   # Discord bot (Ruby)
├── core/      # Shared Ruby library
├── website/   # Rails dashboard (Ruby + Hotwire + Vite)
└── arma/      # Rust extension + Arma 3 SQF mod
```

---

## Developing ESM

### Versions

| Tool       | Version                     |
| ---------- | --------------------------- |
| Ruby       | 3.3                         |
| Rust       | stable                      |
| Node.js    | 18+                         |
| Rails      | 8.1 (installed via Bundler) |
| PostgreSQL | 15+                         |
| Redis      | recent                      |

### Workspace setup

#### Recommended: Nix

The repo ships a unified Nix dev shell that provides Ruby, Rust, Node, database
clients, and the Arma build helpers (`sqfvm`, `armake2`) for every
subdirectory. From the repo root:

```bash
direnv allow   # first time only
nix develop    # or just cd into a subdir; its .envrc delegates here
```

#### Manual setup

- Docker and Docker Compose (arma uses it for its local MySQL/Exile database)
- PostgreSQL 15+ running locally or reachable
- Redis running locally or reachable
- `asdf` with the `ruby` and `nodejs` plugins, or system Ruby 3.3 and Node 18+
- Rust toolchain via `rustup`, plus the extra build targets:
  ```bash
  rustup target add i686-unknown-linux-gnu x86_64-pc-windows-gnu
  ```
- SteamCMD (arma uses it to fetch the Arma 3 dedicated server)
- `sqfvm` and `armake2` on your `PATH` (or build from source)

### Credentials

Register a Discord app at <https://discord.com/developers/applications>:

- **Bot** tab: add the bot and copy the Bot Token.
- **OAuth2 → General**: copy the Client ID and Client Secret.
- **OAuth2 → Redirects**: add `http://localhost:3000/users/auth/discord/callback`.

Register a Steam Web API key at <https://steamcommunity.com/dev>.

Copy the config templates, then fill in the values from above:

```bash
cp service/config/settings.example.yml service/config/settings.local.yml
cp website/config/settings.yml         website/config/settings.local.yml
```

| Where                               | Field                | Value                                                 |
| -------------------------------------| ----------------------| -------------------------------------------------------|
| `service/config/settings.local.yml` | `token`              | Discord Bot Token                                     |
| `service/config/settings.local.yml` | `steam_api_key`      | Steam Web API key                                     |
| `service/config/settings.local.yml` | `developer_guild_id` | Discord guild ID of your dev community                |
| `service/config/settings.local.yml` | `dev_user_allowlist` | Array of Discord user IDs allowed to run dev commands |
| `website/config/settings.local.yml` | `discord.id`         | Discord Client ID                                     |
| `website/config/settings.local.yml` | `discord.secret`     | Discord Client Secret                                 |
| `website/config/settings.local.yml` | `discord.token`      | Discord Bot Token                                     |
| `website/config/settings.local.yml` | `steam.token`        | Steam Web API key                                     |

### First-time bootstrap

Drop Exile's `@Exile/addons` contents into `arma/tools/server/@exile/addons/`.

```bash
cp arma/config.example.yml arma/config.yml    # fill in build paths + DB

bin/setup        # Ruby side: bundles, migrates, seeds the shared Postgres DB
arma/bin/setup   # Arma side: starts MySQL, imports Exile schema, builds extension
```

### Working in each component

#### `service/` (Discord bot)

Receives Discord slash commands and events, dispatches to Arma servers over an
encrypted TCP connection, and persists state to the shared Postgres database.

**Core systems**

- **Commands**: modular system with argument parsing, permission handling, and
  validation
- **Connection**: TCP-based encrypted transport to Arma 3 servers, with
  promise-based request/response handling and automatic reconnection
- **Database**: PostgreSQL via Active Record (schema lives in `core/`)
- **Events**: Discord events and Arma 3 events flow through a unified handler
  pipeline

**Start it:**

```bash
cd service
docker compose up -d postgres-db redis-db
bin/dev
```

#### `core/` (shared Ruby library)

Shared models, business logic, helpers, locales, migrations, and seeds used by
both the service and the website.

Changes here affect both apps, so run both RSpec suites before you commit.

#### `website/` (Rails dashboard)

The Rails 8 app at [esmbot.com](https://esmbot.com).

**Features**

- Server management: configure server settings, mods, rewards, and gambling
  parameters
- Command configuration: enable/disable commands, set cooldowns, manage
  permissions
- Notification system: custom Discord notifications with dynamic variables
- XM8 routing: route in-game notifications to specific Discord channels
- Account management: link Steam/Discord accounts, create aliases, set defaults

**Core systems**

- **Authentication**: Discord OAuth via Devise
- **Authorization**: role-based access control for communities and servers
- **View layer**: SLIM templates with Bootstrap 5.3
- **Interactivity**: Stimulus controllers, Turbo Frames, and Turbo Streams
- **Asset pipeline**: Vite

**Start it:**

Authed views (profile, communities, etc.) call into the service, so start the
bot too if you want to log in.

```bash
cd website
bin/assets &     # vite dev server (background)
bin/dev          # rails server
```

#### `arma/` (Rust extension + SQF mod)

The Rust extension is loaded by the dedicated server and handles TCP
communication with the service plus Exile database operations. The SQF mod
provides the in-game functions and event hooks the extension dispatches to.

Builds run on Linux. Linux x64/x32 and Windows x64 are supported targets;
Windows x32 still needs an actual Windows host (cross-compile from Linux is
in flux).

**Source layout:**

```
arma/
├── src/build/   # Build system
├── src/@esm/    # Arma 3 server mod (SQF + config)
└── src/esm/     # Rust extension
```

**Start it:**

```bash
cd arma
bin/dev    # runs cargo tests, then builds + starts the dedicated server
```

### Common commands

| Task                  | Command (from repo root)                    |
| --------------------- | ------------------------------------------- |
| First-time Ruby setup | `bin/setup`                                 |
| First-time Arma setup | `arma/bin/setup`                            |
| Run service tests     | `cd service && bundle exec rspec`           |
| Run website tests     | `cd website && bundle exec rspec`           |
| Run arma tests        | `cd arma && cargo test --workspace`         |
| Service migrations    | `cd service && bundle exec rake db:migrate` |
| Website migrations    | `cd website && bin/rails db:prepare`        |
| Build arma            | `cd arma && bin/build`                      |
| Start service         | `cd service && bin/dev`                     |
| Start website         | `cd website && bin/dev`                     |
| Start arma + server   | `cd arma && bin/dev`                        |

---

## License

<a rel="license" href="http://creativecommons.org/licenses/by-nc-sa/4.0/">
  <img alt="Creative Commons License" style="border-width:0" src="https://i.creativecommons.org/l/by-nc-sa/4.0/88x31.png" />
</a>

ESM is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike
4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).
