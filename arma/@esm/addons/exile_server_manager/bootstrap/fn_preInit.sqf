/**
 *
 * Function:
 *      ESM_fnc_preInit
 *
 * Description:
 *	    Compiles all the required functions and calls the preInit. Functions can be overwritten by using CfgExileCustomCode.
 *
 * 	    ESM's functions are broken into two categories, ESMs and ESMc for server and client respectfully.
 *	    The reason why this doesn't follow Exile's format of <thing>Server and <thing>Client is because ESMServer and ESMClient look weird to me. That's all.
 *
 * Arguments:
 *      None
 *
 * Examples:
 *      [] call ESM_fnc_preInit;
 *
 * * *
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 Bryan "WolfkillArcadia"
 *
 * *
 *
 * Exile Mod
 * www.exilemod.com
 * © 2015-2021 Exile Mod Team
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.
 *
 **/


private ['_code', '_function', '_file', '_fileContent'];

{
    _code = '';
    _function = _x select 0;
    _file = _x select 1;

    if (isText (missionConfigFile >> 'CfgExileCustomCode' >> _function)) then
    {
        _file = getText (missionConfigFile >> 'CfgExileCustomCode' >> _function);
    };

    _fileContent = preprocessFileLineNumbers _file;

    if (_fileContent isEqualTo '') then
    {
        diag_log (format ['ERROR: Override of %1 in CfgExileCustomCode points to a non-existent file: %2. Defaulting to vanilla ESM code!', _function, _file]);

        _fileContent = preprocessFileLineNumbers (_x select 1);
    };

    _code = compileFinal _fileContent;

    missionNamespace setVariable [_function, _code];
}
forEach
// ["ESMs_", "exile_server_manager\code\ESMs_.sqf"],
[
    ["ESMs_object_embed_addField", "exile_server_manager\code\ESMs_object_embed_addField.sqf"],
    ["ESMs_object_embed_create", "exile_server_manager\code\ESMs_object_embed_create.sqf"],
    ["ESMs_object_message_respond_to", "exile_server_manager\code\ESMs_object_message_respond_to.sqf"],
    ["ESMs_system_command_reward", "exile_server_manager\code\ESMs_system_command_reward.sqf"],
    ["ESMs_system_command_sqf", "exile_server_manager\code\ESMs_system_command_sqf.sqf"],
    ["ESMs_object_message_respond_withError", "exile_server_manager\code\ESMs_object_message_respond_withError.sqf"],
    ["ESMs_system_extension_call", "exile_server_manager\code\ESMs_system_extension_call.sqf"],
    ["ESMs_system_extension_callback", "exile_server_manager\code\ESMs_system_extension_callback.sqf"],
    ["ESMs_system_extension_processResult", "exile_server_manager\code\ESMs_system_extension_processResult.sqf"],
    ["ESMs_system_network_discord_log", "exile_server_manager\code\ESMs_system_network_discord_log.sqf"],
    ["ESMs_system_network_discord_send_to", "exile_server_manager\code\ESMs_system_network_discord_send_to.sqf"],
    ["ESMs_system_process_postInit", "exile_server_manager\code\ESMs_system_process_postInit.sqf"],
	["ESMs_system_process_preInit", "exile_server_manager\code\ESMs_system_process_preInit.sqf"],
    ["ESMs_util_array_all", "exile_server_manager\code\ESMs_util_array_all.sqf"],
    ["ESMs_util_array_isValidHashmap", "exile_server_manager\code\ESMs_util_array_isValidHashmap.sqf"],
    ["ESMs_util_array_map", "exile_server_manager\code\ESMs_util_array_map.sqf"],
    ["ESMs_util_hashmap_fromArray", "exile_server_manager\code\ESMs_util_hashmap_fromArray.sqf"],
    ["ESMs_util_hashmap_get", "exile_server_manager\code\ESMs_util_hashmap_get.sqf"],
    ["ESMs_util_hashmap_toArray", "exile_server_manager\code\ESMs_util_hashmap_toArray.sqf"],
    ["ESMs_util_log", "exile_server_manager\code\ESMs_util_log.sqf"]
];

[] call ESMs_system_process_preInit;
