# Initial version 2.0

## General Changes
- Changed file naming scheme from BIS to Exile
- Added naming scheme for ESM's server and client functions. `ESMs` means a server function, `ESMc` means a client function.
- Renamed `ESM_DatabaseVersion` to `ESM_DatabaseExtension`
- Renamed `ESM_PayTaxPercentage` to `ESM_Taxes_TerritoryPayment`
- Renamed `ESM_UpgradeTaxPercentage` to `ESM_Taxes_TerritoryUpgrade`

### ESMs_system_extension_call
- V1 name: `TODO`
- Arguments:
    - `_arg`: TODO
- Description: TODO

### ESMs_system_extension_callback
- V1 name: `TODO`
- Arguments:
    - `_arg`: TODO
- Description: TODO

### ESMs_system_extenion_processResult
- V1 name: `TODO`
- Arguments:
    - `_arg`: TODO
- Description: TODO

### ESMs_system_process_postInit
- V1 name: `TODO`
- Arguments:
    - `_arg`: TODO
- Description: TODO

### ESMs_system_process_preInit
- V1 name: `TODO`
- Arguments:
    - `_arg`: TODO
- Description: TODO

### ESMs_util_log
- V1 name: `ESM_fnc_log`
- Arguments:
    - `_function`: The name of the calling function. ESM uses a shortened version of the file name, normally the last section.
    - `_message`: The message to log
    - `_logLevel`: The level this log should log at. Valid options: `"debug"`, `"info"`, `"warn"`, `"debug"`. Default: "debug"
- Description: Formats the provided data and prints it to the server RPT
