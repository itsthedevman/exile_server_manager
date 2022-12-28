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


{
    private _code = '';
    private _function = _x select 0;
    private _file = _x select 1;

    if (isText (missionConfigFile >> 'CfgExileCustomCode' >> _function)) then
    {
        _file = getText (missionConfigFile >> 'CfgExileCustomCode' >> _function);
    };

    private _fileContent = preprocessFileLineNumbers _file;

    if (_fileContent isEqualTo '') then
    {
        diag_log (format ['ERROR: Override of %1 in CfgExileCustomCode points to a non-existent file: %2. Defaulting to vanilla ESM code!', _function, _file]);

        _fileContent = preprocessFileLineNumbers (_x select 1);
    };

    _code = compileFinal _fileContent;

    missionNamespace setVariable [_function, _code];
}
forEach
[
    define_fn!("ESMs_object_embed_addField"),
    define_fn!("ESMs_object_embed_create"),
    define_fn!("ESMs_object_message_respond_to"),
    define_fn!("ESMs_command_reward"),
    define_fn!("ESMs_command_sqf"),
    define_fn!("ESMs_object_message_respond_withError"),
    define_fn!("ESMs_system_extension_call"),
    define_fn!("ESMs_system_extension_callback"),
    define_fn!("ESMs_system_extension_processResult"),
    define_fn!("ESMs_system_network_discord_log"),
    define_fn!("ESMs_system_network_discord_send_to"),
    define_fn!("ESMs_system_process_postInit"),
	define_fn!("ESMs_system_process_preInit"),
    define_fn!("ESMs_util_array_all"),
    define_fn!("ESMs_util_array_isValidHashmap"),
    define_fn!("ESMs_util_array_map"),
    define_fn!("ESMs_util_hashmap_fromArray"),
    define_fn!("ESMs_util_hashmap_get"),
    define_fn!("ESMs_util_hashmap_toArray"),
    define_fn!("ESMs_util_log")
];

[] call ESMs_system_process_preInit;
