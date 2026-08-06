# Changelog

All notable changes across the ESM monorepo. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

arma is the only externally-shipped artifact and follows SemVer. service, website, and core have no
version contract and are anchored by date. Year format is Holocene.

---

## [@esm Unreleased]

### Added

- `players_list` query returning each player's stats, connection history, live online/offline status, and whether their player is still alive

### Changed

- `all_territories` query now returns territory level, object count, last-paid timestamp, and stolen/deleted state, and includes territories whose owner account is missing instead of silently excluding them

---

## [Unreleased]

### Added

- **(website)** Server hub: a per-server dashboard that adapts to the viewer, with a self-service card for registered players and management tools for admins
- **(website)** Admin players page: browse recently connected players, search by name or Steam UID, and heal, kill, adjust money, locker, or respect, or reset a stuck player
- **(website)** Player detail page showing health, money, locker, kill/death record, connection history, and territories grouped into stolen, payment due, and up to date. Players see their own; admins see anyone on the server
- **(website)** Admin territories page: every territory on a server, with search and one-click restore for anything Exile has flagged for deletion, plus a detail view where territory admins can pay dues, upgrade, rename, and manage membership
- **(website)** Gambling: bet poptabs, with win/loss streaks, net winnings, and personal and server-wide leaderboards
- **(website)** Admin SQF console: a syntax-highlighted editor for running SQF against the server, all players, or one player by Steam UID
- **(website)** Players can favorite servers, available on the Discover page and the community dashboard
- **(core)** Website actions run through the same command engine as Discord, so per-community permissions, cooldowns, and argument validation apply identically on both surfaces. A command can also declare arguments and help text for one origin only

### Fixed

- **(service)** `/server` shows the map, player count, and game version again. Valve made the Steam query challenge mandatory in December 2020 and the old client never answered it, so those three fields have been missing from every server's details since

---

## @esm v2.0.2 — 12026-07-28

### Removed

- External OpenSSL requirement: the extension no longer links `libssl`/`libcrypto` on any target, so Windows no longer needs `libcrypto-3-x64.dll`/`libssl-3-x64.dll` (or the 32-bit `-3` variants) or the VC++ runtime, and Linux no longer needs `libssl.so.3`/`libcrypto.so.3`
- **BREAKING (rare):** TLS connections to MySQL. Built without a TLS backend, so a `database_uri` requesting encryption (`require_ssl`, `verify_ca`, `verify_identity`) is now rejected with a clear message instead of connecting. Local and LAN MySQL (nearly all setups) are unaffected

### Changed

- Message encryption moved from OpenSSL bindings to the pure-Rust `aes-gcm` crate (same AES-256-GCM and wire format, so no bot/extension protocol change)
- `command_me` query consolidated into `player_info`
- Admin SQF execution now returns the result's type alongside the value, so a boolean or number arrives as its real type rather than a string
- Updated workspace dependencies (tokio 1.47, uuid 1.18, regex 1.11, and others)

### Fixed

- Stale endpoints during reconnect tearing down fresh connections; old endpoints are now tracked and removed before a new dial
- Territory access checks treated territory admins as members in `/territory add`, `promote`, and `remove`
- Remote territory payment limit under-enforced because the payment counter reset to 0 on every server restart (it lived on the in-game territory object, never read back from the database); the counter is now stored in MySQL as the source of truth, with atomic increment and reset

---

## @esm v2.0.1 — 12024-12-22

### Changed

- Fixed client reconnection interval calculation

---

## 12026-08-03

### Added

- **(website)** My Requests page under Account for accepting or declining pending requests without leaving the website, replacing the standalone request-failure page
- **(website)** Live filter on the Command Configuration page for searching commands by name
- **(core)** Error messages for reusing a territory ID that is already taken and for hitting the remote territory payment limit
- **(dev)** `bin/dev`, backed by overmind, runs the website, service, and arma dev processes together in one terminal, each in its own pty so `binding.pry` still works
- **(dev)** One root `docker-compose.yml` for all backing services (Postgres, MySQL, MySQL v1, Redis, NATS on a shared `esm` network), replacing the compose files each component ran independently. The migration generator moved to `bin/create_postgres_migration`
- **(dev)** Local-only `/dev/login/:discord_id` route that signs in as an existing user, skipping Discord OAuth, for local browsing and browser-driven tests
- **(arma, dev)** `bin/paa2png` converts an Arma PAA texture to PNG, or to whatever format its output extension implies
- **(arma, dev)** `--seed-xm8-notify` build flag arms the seeded showcase territories to fire their protection-money XM8 notification once on server start; a routine dev start seeds them already notified
- **(arma, dev)** The dev server launcher runs a heartbeat inside the container so `arma3server` is reaped if the build tool dies, preventing orphaned server processes

### Changed

- **(website)** Website-to-bot calls run over NATS RPC, either synchronously or in the background, with automatic retries and a 2 second timeout, down from 10. Pages that depend on the bot fall back to a safe default instead of erroring when it is unreachable
- **(website)** The website shares a Redis connection with the bot via `REDIS_HOST`, caching cross-process data such as resolved territory-admin membership
- **(website)** The Discover page shows server results before community results, and its search copy leads with server search
- **(service)** Outbound Discord delivery is a fixed pool of four pacing workers draining a shared queue, replacing the two-thread Redis-polling tracker. A slow rate-limit sleep on one channel no longer stalls every other queued message, most noticeable during synchronized multi-server restarts
- **(service)** Requests accepted or declined without an originating channel, such as from the website, reply via the user's DM instead of requiring the original channel to still exist
- **(core)** Territory admins can add a player to a territory directly, the same as a self-add, instead of sending a consent request the player must accept
- **(core)** A community's command cooldown reconciles for everyone currently on it as soon as the new value is saved, instead of waiting until each cooldown is next read
- **(arma, dev)** PBO packing uses HEMTT's native writer instead of shelling out to the vendored armake2 binary, which was removed from the toolchain
- **(arma, dev)** Release workflow split in two: `bin/package` builds and zips every @esm artifact, `bin/release` tags the commit and publishes the built zip. `--use-existing` was dropped in favor of always packaging first, and `bin/package` gained `--skip-updater`
- **(arma, dev)** Dev database seeding generates 500 fake Steam UIDs with realistic connect/disconnect history instead of reading a hand-maintained list, so `config.yml` no longer needs one. Territories get a spread of payment due dates, including a deterministic showcase covering every urgency state
- **(arma, dev)** 32-bit Windows and Linux cross-compile toolchains fixed in the Nix dev shell, so 32-bit extension builds work alongside the existing 64-bit cross-compilation
- **(arma, dev)** `bin/dev` no longer runs `cargo test --workspace` on startup
- **(dev)** The Nix dev shell auto-starts the `nats` and `mysql_db` docker services on entry if they are not already running
- **(dev)** core's test suite shares the `esm_test` Postgres database the service and website suites provision, instead of copying its schema into a separate database

### Fixed

- **(service)** XM8 notifications with multiple destinations record as sent when any destination succeeds. A failed custom route could previously overwrite an already-successful DM delivery and mark the whole notification failed
- **(website)** Production boot failure where Devise drew routes before `ESM::User` was loaded; core now loads once via a `to_prepare` hook
- **(core)** `/territory admin restore` confirms the restore with a reply instead of silently succeeding
- **(core)** `/server sqf` casts boolean and numeric results to their real type instead of returning raw strings
- **(core)** Garbled non-breaking-space characters in several CUP and RHS item names, which broke their display in reward lists

---

## 12026-05-24

### Added

- **(core)** `core/lib/loader.rb` centralizes loading procedures across all services
- **(arma, dev)** `bin/db_migrate` script for easy database migration execution
- **(arma, dev)** `--use-existing` flag in release script to skip rebuild and use existing artifacts
- **(arma, dev)** Build deploy seeds the runtime `additional_logs` config with `test.log` and `/tmp/test.rpt` so `/server admin search_logs` works against the dev container out of the box
- **(arma, dev)** `arma/docker-compose.yml` declares `name: esm_arma` so the compose project namespaces predictably when run alongside other ESM stacks in the monorepo
- **(service)** Community ownership tracking: communities now record their Discord owner, with backfill via `rake community:associate_to_owner_user` and live sync when guild ownership changes
- **(service)** Configurable developer guild via `DEVELOPER_GUILD_ID` (replaces the hardcoded ID previously used to gate developer-only behavior like the ESM welcome message and cross-community support access)
- **(service)** Structured lifecycle logging across the V2 server connection (accept, handshake, request, close, etc.) for clearer operational visibility

### Changed

- **(repo)** Folded the four ESM projects into a single monorepo so domain ownership is explicit and shared code stops needing gem release churn to ship a change. `bot/` is now `service/`; `core/` is no longer packaged as a gem and is loaded via `ESM_*_PATH` env vars.
- **(repo)** Renamed namespaces to reflect domain ownership: `ESM::Connection::*` is now `ESM::Arma::*`; `ESM::API` is now `ESM::Website::API`.
- **(core)** Consolidated extensions and utilities under `core/lib/`
- **(arma, dev)** **BREAKING**: default bot host changed to `host.docker.internal:3003` for better Docker compatibility
- **(arma, dev)** Improved release script with better GitHub CLI authentication handling and error recovery
- **(arma, dev)** Enhanced log reader with dynamic log file discovery; automatically finds ExtDB logs and other log files
- **(arma, dev)** Database seed SQL file now written to build directory for debugging
- **(service)** Reorganized bot boot into ordered `pre_init/` and `post_init/` scripts so library setup, DB connection, autoloader config, and signal handling each live in their own file
- **(service)** Rewrote the spec suite's Discord layer to use FactoryBot-based fakes and inbox/outbox queues instead of `ESM::Test` globals; production and test now share the same code path through `ESM::Discord::Bot`

### Fixed

- **(arma, dev)** Rust toolchain installation in Docker for cross-compilation targets
- **(service)** Connection close now drains its worker thread pool so background work doesn't outlive the socket

### Removed

- **(service)** Capistrano deploy config from the bot

## 12025-08-13 — (bot 2.4.0)

### Added

- **(bot)** Major architectural change: extracted shared code into reusable gems
  - Added `esm_ruby_core` gem dependency for shared model and core logic
  - Added `everythingrb` gem dependency for Ruby core class extensions
- **(bot)** Enhanced V2 server connection system
  - Improved encryption with AES-256-GCM (upgraded from CBC) with authentication tags
  - Added session ID support for enhanced security
  - Implemented heartbeat monitoring and connection management
  - Added signal handler for graceful shutdowns
  - Enhanced connection lifecycle with better error handling
- **(bot)** `user_steam_uid_histories` table for tracking Steam UID changes
- **(bot)** `ruby-lsp` and documentation dependencies (`kramdown`)
- **(bot)** Comprehensive tips system with 20+ helpful user tips
- **(bot)** New API methods: `user_community_permissions` for granular access control
- **(bot)** Enhanced server status embeds for connect/disconnect events
- **(bot)** Community icon URL support

### Changed

- **(bot)** Database migration system: migrations now managed by `esm_ruby_core` gem
- **(bot)** Improved connection reliability
  - Enhanced TCP socket handling with proper header/length prefixed messages
  - Better connection cleanup and resource management
  - Upgraded heartbeat system with reduced intervals (3s vs 5s)
- **(bot)** Enhanced security
  - Session-based authentication for V2 connections
  - Improved encryption with authentication verification
  - Better nonce handling and security validation
- **(bot)** Localization improvements
  - Restructured exception messages for better readability
  - Enhanced multi-line string formatting in YAML
  - Updated server connection/disconnection messaging
- **(bot)** Database schema updates
  - Enhanced `notifications` table with public IDs and improved structure
  - Updated `log_entries` with UUIDs and better indexing
  - Added server settings for configuration management
- **(bot)** Development improvements
  - Updated Nix flake configuration (disabled jemalloc)
  - Reorganized Gemfile groups for better dependency management
  - Enhanced Capistrano deployment for core gem integration

### Removed

- **(bot)** Local implementations of core models (now in `esm_ruby_core`)
- **(bot)** Local Ruby core class extensions (now in `everythingrb`)
- **(bot)** Local utility modules (`ESM::Color`, `ESM::JSON`, `ESM::Regex`, `ESM::Time`)
- **(bot)** Custom logger implementation (using gem version)
- **(bot)** Obsolete VSCode snippets and development artifacts
- **(bot)** Database migration files (moved to core gem)

## @ESM v2.0.0 — 12024-12-20

### Added

- Added Rust based extension with Windows x32/x64 and Linux x32/x64 support
- Added `@esm/sql` directory for storing SQL related files
- Added `@esm/sql/01.sql` for this releases required migrations
- Added helper function `ESMs_object_player_updateRespect` for updating a player's respect on their client
- Added helper function `ESMs_system_account_isKnown` for checking if a steam UID is known
- Added helper function `ESMs_util_command_handleFailure` for handling when a command fails
- Added helper function `ESMs_util_command_handleSuccess` for handling when a command succeeds
- Added helper functions for Arrays
  - `ESMs_util_array_all`: Returns true if all elements match the predicate
  - `ESMs_util_array_isValidHashMap`: Returns true if an array is in the HashMap format
  - `ESMs_util_array_map`: Returns a new array containing the results of the code block
- Added helper functions for HashMaps
  - `ESMs_util_hashmap_dig`: Recursively "digs" into the hashMap to return the value at the end of the list of keys
  - `ESMs_util_hashmap_fromArray`: Creates a HashMap from an array
  - `ESMs_util_hashmap_key`: Returns if the key exists in the hashMap
  - `ESMs_util_hashmap_toArray`: Converts a hashMap to an array
- Added territory admin bypass for `/territory set_id`
- Added end-to-end encryption
- Added Arma 3 stringtable localization
- Added `config.yml` for extension configuration
  - `connection_url`: The URL the extension connects to (used for development)
  - `database_uri`: The full MySQL database URI to the Exile database. Bypass URI discovery through extDB configs
  - `extdb_conf_header_name`: The header name that contains the configuration for extDB
  - `extdb_conf_path`: The full file path to the extDB config file. Bypasses extDB config discovery
  - `extdb_version`: The version of extDB being used. Bypasses extDB version discovery
  - `log_level`: Controls the verbosity ESM logging
  - `log_output`: Controls if ESM will log to RPT, to the extension's log, or both
  - `logging_path`: The full path where ESM will log store its logs
  - `number_locale`: Controls how numbers are formatted
  - `server_mod_name`: The name of @ExileServer on this server. Linux uses `@exileserver`
  - `exile_logs_search_days`: This controls how far back to look when search Exile logs. Defaults to 14 days
  - `additional_logs`: Useful for any extra files that should be searched when using `/server admin search_logs`
- Added extension endpoint `utc_timestamp` for returning the current UTC timestamp
- Added extension endpoint `set_territory_payment_counter` that sets the counter value for an array of territory IDs.
- Added server setting that controls if the locker limit will be taken into account when gambling.
- Added randomized gambling loss messages to stringtable.
- Added `ESMs_system_territory_encodeID` for encoding a territory ID
- Overhauled the XM8 notification system:
  - New database table `xm8_notification` to track all notifications
  - Notifications no longer vanish into the void if ESM isn't connected; they're safely stored until delivery
  - Added a proper queue system: store first, deliver when ready
  - Each notification now has a paper trail from trigger to delivery

### Changed

- Changed database ID encoded hashing algorithm to utilize a unique server key making encoded territory IDs unique to each individual server
- Changed Exile file naming prefix for ESM's server and client functions.
  - `ESMs` (ESMServer) means a server function
  - `ESMc` (ESMClient) means a client function
- Changed file naming scheme from BIS to Exile
- Changed how ESM responds to invalid territory IDs by returning a generic territory not found message
- Balanced gambling algorithm to ensure the player gets back what they gambled.
- Moved embedded SQL in extension into separate SQL files in `@esm/sql/queries`
- Renamed `ESM_DatabaseVersion` to `ESM_DatabaseExtension`
- Renamed `ESM_PayTaxPercentage` to `ESM_Taxes_TerritoryPayment`
- Renamed `ESM_UpgradeTaxPercentage` to `ESM_Taxes_TerritoryUpgrade`
- Replaced `ESM_fnc_addPlayerToTerritory` with `ESMs_command_add`
- Replaced `ESM_fnc_callExtension` with `ESMs_system_extension_call`
- Replaced `ESM_fnc_demotePlayer` with `ESMs_command_demote`
- Replaced `ESM_fnc_exec` with `ESMs_command_sqf`
- Replaced `ESM_fnc_gamble` with `ESMs_command_gamble`
- Replaced `ESM_fnc_getFlagObject` with `ESMs_system_territory_get`
- Replaced `ESM_fnc_handleCallback` with `ESMs_system_extension_callback`
- Replaced `ESM_fnc_hasAccessToTerritory` with `ESMs_system_territory_checkAccess`
- Replaced `ESM_fnc_incrementPaymentCounter` with `ESMs_system_territory_incrementPaymentCounter`
- Replaced `ESM_fnc_log` and `ESM_fnc_logToDLL` with RPT and extension based logging through `ESMs_util_log`
- Replaced `ESM_fnc_logToDiscord` with `ESMs_system_network_discord_log`
- Replaced `ESM_fnc_modifyPlayer` with `ESMs_command_player`
- Replaced `ESM_fnc_payTerritory` with `ESMs_command_pay`
- Replaced `ESM_fnc_postServerInitialization` with `ESMs_system_process_postInit`
- Replaced `ESM_fnc_preInit` with `ESMs_system_process_preInit`
- Replaced `ESM_fnc_promotePlayer` with `ESMs_command_promote`
- Replaced `ESM_fnc_removePlayerFromTerritory` with `ESMs_command_remove`
- Replaced `ESM_fnc_resetPaymentCounter` with `ESMs_system_territory_resetPaymentCounter`
- Replaced `ESM_fnc_respond` with `ESMs_system_message_respond_to`
- Replaced `ESM_fnc_respondWithError` and `ESM_fnc_respondWithErrorCode` with `ESMs_system_message_respond_withError`
- Replaced `ESM_fnc_reward` with `ESMs_command_reward`
- Replaced `ESM_fnc_scalarToString` with extension based function `ESMs_util_number_toString` for speedy formatting
- Replaced `ESM_fnc_sendToChannel` with `ESMs_system_network_discord_send_to`
- Replaced `ESM_fnc_upgradeTerritory` with `ESMs_command_upgrade`
- Replaced `ESM.key` with `esm.key` and changed data structure
- Reworked the reconnection workflow to keep attempting to reconnect without limit.
  - The extension will start trying to reconnect every 15 seconds, gradually increasing the wait time, up to a maximum of 5 minutes between attempts.
- Updated Exile's XM8 functions to the new system
  - `ExileServer_system_xm8_send`
  - `ExileServer_system_xm8_sendBaseRaid`
    - `ExileServer_system_xm8_sendChargePlantStarted`
    - `ExileServer_system_xm8_sendCustom`
    - `ExileServer_system_xm8_sendFlagRestored`
    - `ExileServer_system_xm8_sendFlagStealStarted`
    - `ExileServer_system_xm8_sendFlagStolen`
    - `ExileServer_system_xm8_sendGrindingStarted`
    - `ExileServer_system_xm8_sendHackingStarted`
    - `ExileServer_system_xm8_sendItemSold`
    - `ExileServer_system_xm8_sendProtectionMoneyDue`
    - `ExileServer_system_xm8_sendProtectionMoneyPaid`
- Updated `ExileServer_system_xm8_sendCustom` to accept Embed arguments

### Removed

- Removed `ESM_fnc_attemptReconnect`

## 12024-12-03 — (bot 2.3.2.14)

- **(bot, added)** v2 support for `/server admin search_logs`
- **(bot, removed)** NOT NULL constraint on `log_entries.log_date`

## 12024-12-01 — (bot 2.3.2.13)

- **(bot, added)** v2 support to `/server reward`
- **(bot, added)** html break replacement to `ESM::Message::Data`

## 12024-11-30 — (bot 2.3.2.12)

- **(bot, added)** v2 support to `/server admin modify_player`

## 12024-11-30 — (bot 2.3.2.11)

- **(bot, added)** v2 support to `/server admin find`

## 12024-11-28 — (bot 2.3.2.10)

- **(bot, added)** v2 support to `/server stuck` and `/server admin reset_player`
- **(bot, changed)** Fixed SQL null bug with requests

## 12024-11-27 — (bot 2.3.2.9)

- **(bot, added)** NixOS flake support
- **(bot, added)** XM8 notification support for V2 servers
- **(bot, added)** `ESM::Database.with_connection(&block)`
- **(bot, added)** `ESM::Embed.from_hash!` that can raise `ArgumentError` if the data is invalid
- **(bot, added)** `String#to_deep_h` that recursively converts the String to a Hash
- **(bot, changed)** Updated README.md
- **(bot, changed)** Simplified `ESM::Bot#deliver` usage regarding thread blocking behaviors
- **(bot, changed)** Fixed notification generation fallback
- **(bot, removed)** `extdb_path` from being sent to V2 servers on post_initialization. This setting is handled via the server side config

## 12024-10-15 — (bot 2.3.2.8)

- **(bot, added)** @esm v2 support to `/server my territories`
  - Moderators and Builder lists now only show who is uniquely that role.
    - For example, owner and moderators will not show in the builders list.
- **(bot, added)** Emoji icons to Owner, Moderators, and Builders header in resulting embeds
- **(bot, added)** @esm v2 support to `Exile::Territory`
- **(bot, added)** Comma delimination to renew price and upgrade price in embed from `/server my territories`
- **(bot, changed)** Locale `build_rights` from "Build rights" to "Builders"
- **(bot, changed)** Renamed `map_join` to `join_map` on `Array` and `Hash`
- **(bot, changed)** Fixed an issue where extension errors would not properly format
- **(bot, changed)** `Message#set_metadata` to update instead of overwrite
- **(bot, changed)** Default timestamp formatting to not display seconds
- **(bot, changed)** Updated and fixed a bunch of tests

## 12024-10-05 — (bot 2.3.2.7)

- **(bot, added)** @esm v2 support to `/server gamble`
- **(bot, added)** Server setting `gambling_locker_limit_enabled`
- **(bot, added, dev)** `bin/generate_migration`
- **(bot, added)** Proper error message when the server does not respond in time
- **(bot, added)** Monkey patch `Integer#to_delimited_s` that returns the integer as a delimited string
- **(bot, added, test)** Update SQF for the various gambling server settings
- **(bot, added, test)** Various error handling shared examples
- **(bot, changed, dev)** Decreased timeout time to 2 seconds
- **(bot, changed)** Renamed `ESM::ApplicationCommand#call_sqf_function` to `call_sqf_function!`
- **(bot, changed)** Renamed `ESM::ApplicationCommand#query_exile_database` to `query_exile_database!`
- **(bot, changed)** Rejected promises will raise the exception that caused the rejection instead of being wrapped in `ESM::Exception::RejectedPromise`
- **(bot, changed, test)** All arguments are now converted to a string to match Discord
- **(bot, changed, test)** `spawn_player_for` helper now returns the player's NetID

## 12024-08-03 — (bot 2.3.2.6)

- **(bot, added)** @esm v2 support to `/territory promote_player`
- **(bot, added, test)** Tests for command success logging for `ESMs_command_demote`, `ESMs_command_remove`, and `ESMs_command_upgrade`
- **(bot, added, test)** Tests for `ESM::Message::Player`
- **(bot, added, test)** Shared examples `arma_discord_logging_enabled` and `arma_discord_logging_disabled`
- **(bot, changed)** Fixed bug with `ESM::Message::Player.from` not setting values when given an instance of `ESM::User::Ephemeral`
- **(bot, changed, test)** Moved command "requires registration" check to command examples

## 12024-07-27 — (bot 2.3.2.5)

- **(bot, added)** Hash support to `ApplicationCommand#embed_from_message!`
- **(bot, added)** `ApplicationCommand#embed_from_hash!` alias for `ApplicationCommand#embed_from_message!`
- **(bot, changed)** Moved registration default from `Command::Base` initializer to `ApplicationCommand` to make it clearer to see defaults
- **(bot, changed)** Defaulted `discord_mention` value to steam UID for target metadata on a `Message` when the target is Ephemeral
- **(bot, changed)** `/territory add_player` and `/territory demote_player` to support embed content from SQF

## 12024-07-20 — (bot 2.3.2.4)

- **(bot, added)** @esm v2 support to `/territory admin restore`
- **(bot, added, test)** `ESM::ExileContainer` and `ESM::ExileConstruction` models and factories
- **(bot, added, test)** `error_territory_id_does_not_exist` command example
- **(bot, changed)** Improved `ESM::Arma::ClassLookup`
  - Added auto-caching
  - Moved container class names from `exile_construction` into `exile_container`

## 12024-07-13 — (bot 2.3.2.3)

- **(bot, added)** @esm v2 support to `/territory pay`
- **(bot, added)** `ApplicationCommand#embed_from_message!`
  - This helper method takes a Message from the Arma 3 server, validates the data, and converts it to an Embed.
  - Invalid Embed data will result in a error log and a message to the user informing them that the server has something they need to fix
- **(bot, added)** `Symbol#quoted` that returns the string variant of the symbol surrounded in double quotes.
- **(bot, added, test)** Specs for `ESMs_system_territory_incrementPaymentCounter`
- **(bot, added, test)** Specs for `ESMs_system_territory_resetPaymentCounter`
- **(bot, added, test)** Spec for `ESMs_util_array_map` 'filter' argument
- **(bot, added, test)** Command example specs for FlagStolen, and TooPoor
- **(bot, changed)** Migrated `ESM::Command::Territory::Remove` and `ESM::Command::Territory::Upgrade` to utilize `#embed_from_message!`
- **(bot, changed, test)** Moved pay_spec.rb from `server` to `territory`
- **(bot, changed, test)** Improved `ExileTerritory` variable update SQF

## 12024-06-30 — (bot 2.3.2.2)

- **(bot, added)** @esm v2 support to `/territory remove_player`
- **(bot, added, test)** `ESM::ExileTerritory#add_moderators!` and `ESM::ExileTerritory#add_builders!`.
  - Aliases: `#add_moderator!` and `#add_builder!`

## 12024-06-29 — (bot 2.3.2.1)

- **(bot, added)** Alias `#run_database_query` for helper method `#query_exile_database`
- **(bot, added)** @esm v2 support to `/territory set_id`
- **(bot, added, test)** `ESM::ExileTerritory#change_owner`
- **(bot, changed, test)** How territory admins are modified
- **(bot, removed)** Setting command metadata on query messages

## 12024-06-20 — (bot 2.3.2)

- **(bot, added)** `CHANGELOG.md`
- **(bot, added)** `.env.example` and updated `config.yml` with new options
- **(bot, added)** V2 support for `ESM::Command::Territory::Upgrade` and added specs
- **(bot, added)** `ESM::Connection::Client#on_disconnect` handler
- **(bot, added)** `:timeout` kwarg on `ESM::Connection::Client#send_request`
- **(bot, added)** Heartbeat task for checking if v2 connections are still alive
- **(bot, added)** `ESM::Embed#from_hash`, and specs, to centralize creating embeds from hashes
- **(bot, added)** Arma 3 line break (`<br/>`, `<br />`, `<br></br>`) replacement support to `ESM::Arma::HashMap`.
  - This allows locales to contain line breaks
- **(bot, added, test)** Specs for `ESMs_util_number_toString`
- **(bot, added)** `ESM::ServerSetting#update_arma` functionality for specs
- **(bot, added)** Rake task `commands:list` for listing all commands
- **(bot, changed)** Updated README.md
- **(bot, changed)** Updated dependencies
- **(bot, changed)** Moved command registration process out of `bin/setup` into rake `commands:seed`
- **(bot, changed)** `ESM::Connection::Client` lifecycle error to not warn on invalid key
- **(bot, changed)** Renamed `ESM::Exception::DataError` to `ESM::Exception::ApplicationError`
- **(bot, changed)** Adjusted spec for `ESMs_system_territory_checkAccess` because of changes to call signature
- **(bot, changed)** Reworked RSpec config into its own file
- **(bot, changed)** Refactored how connection methods are defined on user to fix issues with RSpec updates
- **(bot, changed, test)** Standardized generic testing for command errors from Arma into RSpec examples
- **(bot, changed)** Improved `ESM::ExileTerritory#update_arma` to have a one-to-one mapping with object variables
- **(bot, removed)** Environment variable `PRINT_LOG`
- **(bot, removed)** Redundant `_context` and `_examples` for RSpec context and examples
- **(bot, removed)** `ESM::Callbacks`

## 12024-05-29 — (bot 2.3.1)
