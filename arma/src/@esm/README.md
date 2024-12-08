# `@esm` Installation

## SQL Setup
Located in `sql`

### Database Migrations
- `01.sql`: Required for fresh installations. Skip if migrating from v1
- `02.sql`: Required for all installations, including v1 migrations

### Queries Directory
The `queries` directory contains SQL files used by the extension. These files do not require manual execution.

## Optional Modules
Located in `optionals`

### xm8_notification_flag_steal_started
Adds XM8 notifications when players attempt to steal territory flags.

#### Installation
1. Copy `ExileClient_action_stealFlag_duration.sqf` to your mission directory
2. Add the network message configuration to your mission's `config.cpp`:
   ```cpp
   class CfgNetworkMessages
   {
       // Copy contents from optionals/xm8_notification_flag_steal_started/CfgNetworkMessages.cpp
   }
   ```
   > If `CfgNetworkMessages` doesn't exist in your config, create it.

3. Ensure these PBOs are loaded:
   - `exile_server_xm8.pbo`
   - `exile_server_flag_steal_started.pbo`

> Note: If you have existing overwrites, carefully merge any changes
