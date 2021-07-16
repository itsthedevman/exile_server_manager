/**
 * Pre-Initialization
 *	Compiles all the required functions and calls the preInit. Functions can be overwriten by using CfgExileCustomCode.
 *
 * 	ESM's functions are broken into two categories, ESMs and ESMc for server and client respectfully.
 *	The reason why this doesn't follow Exile's format of Server and Client is because ESMServer and ESMClient look weird to me. That's all.
 */

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
[
	// ["ESMs_", "exile_server_manager\code\ESMs_"],
    ["ESMs_system_extension_call", "exile_server_manager\code\ESMs_system_extension_call.sqf"],
    ["ESMs_system_extension_callback", "exile_server_manager\code\ESMs_system_extension_callback.sqf"],
    ["ESMs_system_extension_processResult", "exile_server_manager\code\ESMs_system_extension_processResult.sqf"],
	["ESMs_system_process_preInit", "exile_server_manager\code\ESMs_system_process_preInit.sqf"],
    ["ESMs_system_process_postInit", "exile_server_manager\code\ESMs_system_process_postInit.sqf"],
    ["ESMs_util_log", "exile_server_manager\code\ESMs_util_log.sqf"]
];

call ESMs_system_process_preInit;
