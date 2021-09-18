/**
 *
 * Function:
 *      ESMs_system_process_preInit
 *
 * Description:
 *      Preps required variables and starts the client
 *
 * Arguments:
 *      None
 *
 * Examples:
 *      [] call ESMs_system_process_preInit;
 *
 * * *
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 Bryan "WolfkillArcadia"
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 *
 **/

// For controlling which calls log
ESM_LogLevel = "log_level" call ESMs_system_extension_call;
ESM_LogLevelLookup = createHashMapFromArray [["error", 0], ["warn", 1], ["info", 2], ["debug", 3], ["trace", 4]];

// Cache the territory prices to make calculating upgrade costs faster
private _territory_data = [];
{
	_territory_data pushBack [
		["level", _forEachIndex + 1],
		["purchase_price", _x select 0],
		["radius", _x select 1],
		["object_count", _x select 2]
	];
}
forEach (getArray(missionConfigFile >> "CfgTerritories" >> "prices"));

// Bind the callback to enable the extension to communicate with the a3 server
addMissionEventHandler ["ExtensionCallback", {
	params ["_name", "_function", "_data"];

	if (_name isEqualTo "exile_server_manager") then
	{
		[_function, _data] spawn ESMs_system_extension_callback;
	};
}];

// Send the data to the client
[
	// Rust function
	"pre_init",

	// server_name
	serverName,

	// price_per_object
	getNumber(missionConfigFile >> "CfgTerritories" >> "popTabAmountPerObject"),

	// territory_lifetime
	getNumber(configFile >> "CfgSettings" >> "GarbageCollector" >> "Database" >> "territoryLifeTime"),

	// territory_data
	_territory_data,

	// vg_enabled
	getNumber(missionConfigFile >> "CfgVirtualGarage" >> "enableVirtualGarage") isEqualTo 0,

	// vg_max_sizes
	getArray(missionConfigFile >> "CfgVirtualGarage" >> "numberOfVehicles")
] call ESMs_system_extension_call;

true
