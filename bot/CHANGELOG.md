# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Removed

## [2.3.2.6] - 2024-08-03

### Added
- Added @esm v2 support to `/territory promote_player`
- Tests - Added tests for command success logging for `ESMs_command_demote`, `ESMs_command_remove`, and `ESMs_command_upgrade`
- Tests - Added tests for `ESM::Message::Player`
- Tests - Added shared examples `arma_discord_logging_enabled` and `arma_discord_logging_disabled`

### Changed
- Fixed bug with `ESM::Message::Player.from` not setting values when given an instance of `ESM::User::Ephemeral`
- Tests - Moved command "requires registration" check to command examples

## [2.3.2.5] - 2024-07-27

### Added
- Added Hash support to `ApplicationCommand#embed_from_message!`
- Added `ApplicationCommand#embed_from_hash!` alias for `ApplicationCommand#embed_from_message!`

### Changed
- Moved registration default from `Command::Base` initializer to `ApplicationCommand` to make it clearer to see defaults
- Defaulted `discord_mention` value to steam UID for target metadata on a `Message` when the target is Ephemeral
- Changed `/territory add_player` and `/territory demote_player` to support embed content from SQF

## [2.3.2.4] - 2024-07-20

### Added
- Added @esm v2 support to `/territory admin restore`
- Tests - Added `ESM::ExileContainer` and `ESM::ExileConstruction` models and factories
- Tests - Added `error_territory_id_does_not_exist` command example

### Changed
- Improved `ESM::Arma::ClassLookup`
    - Added auto-caching
    - Moved container class names from `exile_construction` into `exile_container`

### Removed

## [2.3.2.3] - 2024-07-13

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

## [2.3.2.2] - 2024-06-30

### Added
- Added @esm v2 support to `/territory remove_player`
- Tests - Added `ESM::ExileTerritory#add_moderators!` and `ESM::ExileTerritory#add_builders!`.
    - Aliases: `#add_moderator!` and `#add_builder!`

## [2.3.2.1] - 2024-06-29

### Added
- Added alias `#run_database_query` for helper method `#query_exile_database`
- Added @esm v2 support to `/territory set_id`
- Tests - Added `ESM::ExileTerritory#change_owner`

### Changed
- Tests - Changed how territory admins are modified

### Removed
- Removed setting command metadata on query messages

## [2.3.2] - 2024-06-20

### Added
- Added `CHANGELOG.md`
- Added `.env.example` and updated `config.yml` with new options
- Added V2 support for `ESM::Command::Territory::Upgrade` and added specs
- Added `ESM::Connection::Client#on_disconnect` handler
- Added  `:timeout` kwarg on `ESM::Connection::Client#send_request`
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

## [2.3.1] - 2024-05-29

[Unreleased]: https://github.com/itsthedevman/esm_bot/compare/main..v2.3.2.6
[2.3.2.6]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.6..v2.3.2.5
[2.3.2.5]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.5..v2.3.2.4
[2.3.2.4]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.4..v2.3.2.3
[2.3.2.3]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.3..v2.3.2.2
[2.3.2.2]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.2..v2.3.2.1
[2.3.2.1]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2.1..v2.3.2
[2.3.2]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2..v2.3.1
[2.3.1]: https://github.com/itsthedevman/esm_bot/compare/v2.3.1..v2.3.0
