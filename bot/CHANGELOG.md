# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Removed

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

[Unreleased]: https://github.com/itsthedevman/esm_bot/compare/main..v2.3.2
[2.3.2]: https://github.com/itsthedevman/esm_bot/compare/v2.3.2..v2.3.1
[2.3.1]: https://github.com/itsthedevman/esm_bot/compare/v2.3.1..v2.3.0
