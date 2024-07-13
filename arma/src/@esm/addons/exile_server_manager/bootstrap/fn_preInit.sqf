/* ----------------------------------------------------------------------------
Function:
    ESM_fnc_preInit

Description:
    Compiles all the required functions and calls the preInit. Functions can be overwritten by using CfgExileCustomCode.

    ESM's functions are broken into two categories, ESMs and ESMc for server and client respectfully.
    The reason why this doesn't follow Exile's format of <thing>Server and <thing>Client is because ESMServer and ESMClient look weird to me. That's all.

Parameters:
    _this - [Nothing]

Returns:
    Nothing

Examples:
    (begin example)

        [] call ESM_fnc_preInit;

    (end)

Author:
    Exile Mod
    www.exilemod.com
    © 2015-current_year!() Exile Mod Team

    This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
    To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

Co-author:
    Exile Server Manager
    www.esmbot.com
    © 2018-current_year!() Bryan "WolfkillArcadia"

    This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
    To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.
---------------------------------------------------------------------------- */

{
    private _function = _x select 0;
    private _file = _x select 1;

    if (isText (missionConfigFile >> "CfgExileCustomCode" >> _function)) then
    {
        _file = getText (missionConfigFile >> "CfgExileCustomCode" >> _function);
    };

    private _fileContent = preprocessFileLineNumbers _file;

    if (_fileContent isEqualTo "") then
    {
        diag_log (
            format [
                "ERROR | Override of %1 in CfgExileCustomCode points to a non-existent file: %2. Defaulting to vanilla Exile Server Manager code!",
                _function,
                _file
            ]
        );

        _fileContent = preprocessFileLineNumbers (_x select 1);
    };

    missionNamespace setVariable [_function, compileFinal _fileContent];
}
forEach
[
    define_fn!("ESMs_command_add"),
    define_fn!("ESMs_command_demote"),
    define_fn!("ESMs_command_pay"),
    define_fn!("ESMs_command_remove"),
    define_fn!("ESMs_command_reward"),
    define_fn!("ESMs_command_sqf"),
    define_fn!("ESMs_command_upgrade"),
    define_fn!("ESMs_system_account_isKnown"),
    define_fn!("ESMs_system_extension_call"),
    define_fn!("ESMs_system_extension_callback"),
    define_fn!("ESMs_system_extension_processResult"),
    define_fn!("ESMs_system_message_respond_to"),
    define_fn!("ESMs_system_message_respond_withError"),
    define_fn!("ESMs_system_network_discord_log"),
    define_fn!("ESMs_system_network_discord_send_to"),
	define_fn!("ESMs_system_process_preInit"),
    define_fn!("ESMs_system_process_postInit"),
    define_fn!("ESMs_system_territory_checkAccess"),
    define_fn!("ESMs_system_territory_get"),
    define_fn!("ESMs_system_territory_incrementPaymentCounter"),
    define_fn!("ESMs_system_territory_resetPaymentCounter"),
    define_fn!("ESMs_util_array_all"),
    define_fn!("ESMs_util_array_isValidHashmap"),
    define_fn!("ESMs_util_array_map"),
    define_fn!("ESMs_util_command_handleFailure"),
    define_fn!("ESMs_util_command_handleSuccess"),
    define_fn!("ESMs_util_embed_addField"),
    define_fn!("ESMs_util_embed_create"),
    define_fn!("ESMs_util_embed_setColor"),
    define_fn!("ESMs_util_embed_setDescription"),
    define_fn!("ESMs_util_embed_setTitle"),
    define_fn!("ESMs_util_extension_formatArmaError"),
    define_fn!("ESMs_util_extension_formatError"),
    define_fn!("ESMs_util_hashmap_dig"),
    define_fn!("ESMs_util_hashmap_fromArray"),
    define_fn!("ESMs_util_hashmap_key"),
    define_fn!("ESMs_util_hashmap_toArray"),
    define_fn!("ESMs_util_log"),
    define_fn!("ESMs_util_number_toString")
];

[] call ESMs_system_process_preInit;
