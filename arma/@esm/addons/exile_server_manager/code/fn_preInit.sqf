ESM_UseExtDB3 = false;
ESM_UseExileThreading = false;
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

// Get all the prices and build an array of objects
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

// Add a MissionEventHandler to allow callbacks from the DLL
addMissionEventHandler ["ExtensionCallback", {
	params ["_name", "_function", "_data"];

	if (_name isEqualTo "exile_server_manager") then
	{
		[_function, _data] call ESM_fnc_handleCallback;
	};
}];

// Send the data to the server
[
	// Function
	"pre_init",

	// server_name
	serverName,

	// price_per_object
	getNumber(missionConfigFile >> "CfgTerritories" >> "popTabAmountPerObject"),

	// territory_lifetime
	getNumber(configFile >> "CfgSettings" >> "GarbageCollector" >> "Database" >> "territoryLifeTime"),

	// territory_data
	_territory_data
] call ESM_fnc_callExtension;

true
