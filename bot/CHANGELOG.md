# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Removed

## [2.4.0] - 2025-08-13

### Added

- **Major architectural change**: Extracted shared code into reusable gems
  - Added `esm_ruby_core` gem dependency for shared model and core logic
  - Added `everythingrb` gem dependency for Ruby core class extensions
- **Enhanced V2 server connection system**
  - Improved encryption with AES-256-GCM (upgraded from CBC) with authentication tags
  - Added session ID support for enhanced security
  - Implemented heartbeat monitoring and connection management
  - Added signal handler for graceful shutdowns
  - Enhanced connection lifecycle with better error handling
- Added `user_steam_uid_histories` table for tracking Steam UID changes
- Added `ruby-lsp` and documentation dependencies (`kramdown`)
- Added comprehensive tips system with 20+ helpful user tips
- Added new API methods: `user_community_permissions` for granular access control
- Added enhanced server status embeds for connect/disconnect events
- Added community icon URL support

### Changed

- **Database migration system**: Migrations now managed by `esm_ruby_core` gem
- **Improved connection reliability**
  - Enhanced TCP socket handling with proper header/length prefixed messages
  - Better connection cleanup and resource management
  - Upgraded heartbeat system with reduced intervals (3s vs 5s)
- **Enhanced security**
  - Session-based authentication for V2 connections
  - Improved encryption with authentication verification
  - Better nonce handling and security validation
- **Localization improvements**
  - Restructured exception messages for better readability
  - Enhanced multi-line string formatting in YAML
  - Updated server connection/disconnection messaging
- **Database schema updates**
  - Enhanced `notifications` table with public IDs and improved structure
  - Updated `log_entries` with UUIDs and better indexing
  - Added server settings for configuration management
- **Development improvements**
  - Updated Nix flake configuration (disabled jemalloc)
  - Reorganized Gemfile groups for better dependency management
  - Enhanced Capistrano deployment for core gem integration

### Removed

- Removed local implementations of core models (now in `esm_ruby_core`)
- Removed local Ruby core class extensions (now in `everythingrb`)
- Removed local utility modules (`ESM::Color`, `ESM::JSON`, `ESM::Regex`, `ESM::Time`)
- Removed custom logger implementation (using gem version)
- Removed obsolete VSCode snippets and development artifacts
- Removed database migration files (moved to core gem)

## [2.3.2.14] - 12024-12-03

### Added

- Added v2 support for `/server admin search_logs`

### Removed

- Removed NOT NULL constraint on `log_entries.log_date`

## [2.3.2.13] - 12024-12-01

### Added

- Added v2 support to `/server reward`
- Added html break replacement to `ESM::Message::Data`

## [2.3.2.12] - 12024-11-30

### Added

- Added v2 support to `/server admin modify_player`

## [2.3.2.11] - 12024-11-30

### Added

- Added v2 support to `/server admin find`

## [2.3.2.10] - 12024-11-28

### Added

- Added v2 support to `/server stuck` and `/server admin reset_player`

### Changed

- Fixed SQL null bug with requests

## [2.3.2.9] - 12024-11-27

### Added

- Added NixOS flake support
- Added XM8 notification support for V2 servers
- Added `ESM::Database.with_connection(&block)`
- Added `ESM::Embed.from_hash!` that can raise `ArgumentError` if the data is invalid
- Added `String#to_deep_h` that recursively converts the String to a Hash

### Changed

- Updated README.md
- Simplified `ESM::Bot#deliver` usage regarding thread blocking behaviors
- Fixed notification generation fallback

### Removed

- Removed `extdb_path` from being sent to V2 servers on post_initialization. This setting is handled via the server side config

## [2.3.2.8] - 12024-10-15

### Added

- Added @esm v2 support to `/server my territories`
  - Moderators and Builder lists now only show who is uniquely that role.
    - For example, owner and moderators will not show in the builders list.
- Added emoji icons to Owner, Moderators, and Builders header in resulting embeds
- Added @esm v2 support to `Exile::Territory`
- Added comma delimination to renew price and upgrade price in embed from `/server my territories`

### Changed

- Changed locale `build_rights` from "Build rights" to "Builders"
- Renamed `map_join` to `join_map` on `Array` and `Hash`
- Fixed an issue where extension errors would not properly format
- Changed `Message#set_metadata` to update instead of overwrite
- Changed default timestamp formatting to not display seconds
- Updated and fixed a bunch of tests

## [2.3.2.7] - 12024-10-05

### Added

- Added @esm v2 support to `/server gamble`
- Added server setting `gambling_locker_limit_enabled`
- Dev - Added `bin/generate_migration`
- Added proper error message when the server does not respond in time.
- Added monkey patch `Integer#to_delimited_s` that returns the integer as a delimited string
- Tests - Added update SQF for the various gambling server settings
- Tests - Added various error handling shared examples

### Changed

- Dev - Decreased timeout time to 2 seconds
- Renamed `ESM::ApplicationCommand#call_sqf_function` to `call_sqf_function!`
- Renamed `ESM::ApplicationCommand#query_exile_database` to `query_exile_database!`
- Rejected promises will raise the exception that caused the rejection instead of being wrapped in `ESM::Exception::RejectedPromise`
- Tests - All arguments are now converted to a string to match Discord
- Tests - `spawn_player_for` helper now returns the player's NetID

## [2.3.2.6] - 12024-08-03

### Added

- Added @esm v2 support to `/territory promote_player`
- Tests - Added tests for command success logging for `ESMs_command_demote`, `ESMs_command_remove`, and `ESMs_command_upgrade`
- Tests - Added tests for `ESM::Message::Player`
- Tests - Added shared examples `arma_discord_logging_enabled` and `arma_discord_logging_disabled`

### Changed

- Fixed bug with `ESM::Message::Player.from` not setting values when given an instance of `ESM::User::Ephemeral`
- Tests - Moved command "requires registration" check to command examples

## [2.3.2.5] - 12024-07-27

### Added

- Added Hash support to `ApplicationCommand#embed_from_message!`
- Added `ApplicationCommand#embed_from_hash!` alias for `ApplicationCommand#embed_from_message!`

### Changed

- Moved registration default from `Command::Base` initializer to `ApplicationCommand` to make it clearer to see defaults
- Defaulted `discord_mention` value to steam UID for target metadata on a `Message` when the target is Ephemeral
- Changed `/territory add_player` and `/territory demote_player` to support embed content from SQF

## [2.3.2.4] - 12024-07-20

### Added

- Added @esm v2 support to `/territory admin restore`
- Tests - Added `ESM::ExileContainer` and `ESM::ExileConstruction` models and factories
- Tests - Added `error_territory_id_does_not_exist` command example

### Changed

- Improved `ESM::Arma::ClassLookup`
  - Added auto-caching
  - Moved container class names from `exile_construction` into `exile_container`

### Removed

## [2.3.2.3] - 12024-07-13

### Added

- Added @esm v2 support to `/territory pay`
- Added `ApplicationCommand#embed_from_message!`
  - This helper method takes a Message from the Arma 3 server, validates the data, and converts it to an Embed.
  - Invalid Embed data will result in a error log and a message to the user informing them that the server has something they need to fix
- Added `Symbol#quoted` that returns the string variant of the symbol surrounded in double quotes.
- Tests - Added specs for `ESMs_system_territory_incrementPaymentCounter`
- Tests - Added specs for `ESMs_system_territory_resetPaymentCounter`
- Tests - Added spec for `ESMs_util_array_map` 'filter' argument
- Tests - Added command example specs for FlagStolen, and TooPoor

### Changed

- Migrated `ESM::Command::Territory::Remove` and `ESM::Command::Territory::Upgrade` to utilize `#embed_from_message!`
- Tests - Moved pay_spec.rb from `server` to `territory`
- Tests - Improved `ExileTerritory` variable update SQF

## [2.3.2.2] - 12024-06-30

### Added

- Added @esm v2 support to `/territory remove_player`
- Tests - Added `ESM::ExileTerritory#add_moderators!` and `ESM::ExileTerritory#add_builders!`.
  - Aliases: `#add_moderator!` and `#add_builder!`

## [2.3.2.1] - 12024-06-29

### Added

- Added alias `#run_database_query` for helper method `#query_exile_database`
- Added @esm v2 support to `/territory set_id`
- Tests - Added `ESM::ExileTerritory#change_owner`

### Changed

- Tests - Changed how territory admins are modified

### Removed

- Removed setting command metadata on query messages

## [2.3.2] - 12024-06-20

### Added

- Added `CHANGELOG.md`
- Added `.env.example` and updated `config.yml` with new options
- Added V2 support for `ESM::Command::Territory::Upgrade` and added specs
- Added `ESM::Connection::Client#on_disconnect` handler
- Added `:timeout` kwarg on `ESM::Connection::Client#send_request`
- Added heartbeat task for checking if v2 connections are still alive
- Added `ESM::Embed#from_hash`, and specs, to centralize creating embeds from hashes
- Added Arma 3 line break (`<br/>`, `<br />`, `<br></br>`) replacement support to `ESM::Arma::HashMap`.
  - This allows locales to contain line breaks
- Added specs for `ESMs_util_number_toString`
- Added `ESM::ServerSetting#update_arma` functionality for specs
- Added rake task `commands:list` for listing all commands

### Changed

- Updated README.md
- Updated dependencies
- Moved command registration process out of `bin/setup` into rake `commands:seed`
- Changed `ESM::Connection::Client` lifecycle error to not warn on invalid key
- Renamed `ESM::Exception::DataError` to `ESM::Exception::ApplicationError`
- Adjusted spec for `ESMs_system_territory_checkAccess` because of changes to call signature
- Reworked RSpec config into its own file
- Refactored how connection methods are defined on user to fix issues with RSpec updates
- Standardized generic testing for command errors from Arma into RSpec examples
- Improved `ESM::ExileTerritory#update_arma` to have a one-to-one mapping with object variables

### Removed

- Removed environment variable `PRINT_LOG`
- Removed redundant `_context` and `_examples` for RSpec context and examples
- Removed `ESM::Callbacks`

## [2.3.1] - 12024-05-29

[Unreleased]: https://github.com/itsthedevman/esm_bot/compare/main..v2.4.0
[2.3.2.13]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.12..v2.4.0
[2.3.2.12]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.11..v2.3.2.12
[2.3.2.11]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.10..v2.3.2.11
[2.3.2.10]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.9..v2.3.2.10
[2.3.2.9]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.8..v2.3.2.9
[2.3.2.8]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.7..v2.3.2.8
[2.3.2.7]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.6..v2.3.2.7
[2.3.2.6]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.6..v2.3.2.5
[2.3.2.5]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.5..v2.3.2.4
[2.3.2.4]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.4..v2.3.2.3
[2.3.2.3]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.3..v2.3.2.2
[2.3.2.2]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.2..v2.3.2.1
[2.3.2.1]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.1..v2.3.2
[2.3.2]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2..v2.3.1
[2.3.1]: https://github.com/itsthedevman/esm_bot/compare/v2.3.1..v2.3.0
