# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

### Changed

### Removed

## [2.0.0] - 12024-12-20
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
    - Notifications no longer vanish into the void if ESM isn't connected - they're safely stored until delivery
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

[Unreleased]: https://github.com/itsthedevman/esm_arma/compare/v2.0.0..main
[2.0.0]: https://github.com/itsthedevman/esm_arma/compare/401f167e731c4bcb8ceb76a1a54cb3b4d343d48b..v2.0.0
