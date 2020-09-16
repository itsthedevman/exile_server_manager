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

private _return = ["initialize", _data] call ESM_fnc_callExtension;

// Init has been moved to fn_postServerInitialization
if (_return select 0) then
{
	["fn_preInit", (_return select 1) select 0] call ESM_fnc_log;
	
	// Create a temporary request checker
	[] spawn 
	{
		waitUntil {PublicServerIsLoaded};
		ESM_RequestThread = [0.1, ESM_fnc_checkForRequests, [], true] call ExileServer_system_thread_addTask;
	};
}
else 
{
	["fn_preInit", format["Failed to initialize!!! Reason: %1", (_return select 1) select 0]] call ESM_fnc_log;
};

true