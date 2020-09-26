ESM_RequestThread = -1;
ESM_UseExtDB3 = false;
ESM_UseExileThreading = false;
ESM_ThreadDelay = 0.1;
ESM_Logging_AddPlayerToTerritory = false;
ESM_Logging_DemotePlayer = false;
ESM_Logging_Gamble = false;
ESM_Logging_PayTerritory = false;
ESM_Logging_PromotePlayer = false;
ESM_Logging_RemovePlayerFromTerritory = false;
ESM_Logging_UpgradeTerritory = false;
ESM_Logging_ModifyPlayer = false;
ESM_GambleWinPercentage = 0.35;
ESM_PayTaxPercentage = 0;
ESM_UpgradeTaxPercentage = 0;
ESM_DatabaseVersion = "extDB2";
ESM_TerritoryManagementUIDs = [];
ESM_Initialized = false;
ESM_ServerID = "";
ESM_CommunityID = "";

private _restart = getArray(configFile >> "CfgSettings" >> "RCON" >> "restartTimer");

// Data to be sent to the server
private _data =
[
	["server_name", serverName],
	["price_per_object", getNumber(missionConfigFile >> "CfgTerritories" >> "popTabAmountPerObject")],
	["territory_lifetime", getNumber(configFile >> "CfgSettings" >> "GarbageCollector" >> "Database" >> "territoryLifeTime")],
	["server_restart_hour", _restart select 0],
	["server_restart_min", _restart select 1]
];

// Get all the prices and send them as a flat string
{
	_data pushBack [format["purchase_price_%1", _forEachIndex + 1], (_x select 0)];
	_data pushBack [format["radius_%1", _forEachIndex + 1], (_x select 1)];
	_data pushBack [format["object_count_%1", _forEachIndex + 1], (_x select 2)];
}
forEach (getArray(missionConfigFile >> "CfgTerritories" >> "prices"));

// Add a MissionEventHandler to allow callbacks from the DLL
addMissionEventHandler ["ExtensionCallback", {
	params ["_name", "_function", "_data"];

	if (_name isEqualTo "esm") then
	{
		[_function, _data] call ESM_fnc_handleCallback;
	};
}];

["pre_init", _data] call ESM_fnc_callExtension;

true
