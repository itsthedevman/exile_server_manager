/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Fires from a request when the player wants to upgrade the territory.
*/

params ["_commandID", "_authorInfo", "_tid", "_flagID", "_playerUID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

try
{
	private _flagObject = _flagID call ESM_fnc_getFlagObject;
	
	if (isNull _flagObject) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to upgrade territory `ID:%3`, but the flag does not exist. This could be because they typed in the wrong ID or the territory has been deleted.", _authorTag, _playerUID, _tid], 
			format["%1, I am unable to find that territory. Please confirm you have typed in the territory ID in correctly and that you have not failed to make a protection payment.", _authorTag]
		];
	};

	if !([_flagObject, _playerUID, "moderator"] call ESM_fnc_hasAccessToTerritory) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to upgrade territory `ID:%3`, but they don't have permission!", _authorTag, _playerUID, _tid], 
			format["%1, you do not have permission to upgrade this territory.", _authorTag]
		];
	};
	
	private _flagStolen = _flagObject getVariable ["ExileFlagStolen", 0];
	
	if (_flagStolen isEqualTo 1) then
	{
		throw [
			"", 
			format["%1, your flag has been stolen! You need to get it back before you can upgrade your base", _authorTag]
		];
	};

	private _level = _flagObject getVariable ["ExileTerritoryLevel",0];

	private _territoryConfig = getArray(missionConfigFile >> "CfgTerritories" >> "Prices");
	private _territoryLevels = count _territoryConfig;

	if (_territoryLevels < (_level + 1)) then
	{
		throw [
			"", 
			format["%1, your base is already at the highest level", _authorTag]
		];
	};

	private _territoryPrice = (_territoryConfig select _level) select 0;
	private _territoryRange = (_territoryConfig select _level) select 1;

	// Add a tax
	private _tax = round(_territoryPrice * ESM_UpgradeTaxPercentage);
	_territoryPrice = _territoryPrice + _tax;
	
	_playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;
	private _playerMoney = 0;
	
	// The player is online
	if !(isNull(_playerObject)) then 
	{
		_playerMoney = _playerObject getVariable ["ExileLocker",0];
		
		if (_playerMoney < _territoryPrice) then
		{
			throw [
				"",
				format["%1, you do not have enough poptabs in your locker, it costs **%2** and you have **%3**", _authorTag, _territoryPrice call ESM_fnc_scalarToString, _playerMoney call ESM_fnc_scalarToString]
			];
		};

		_playerMoney = _playerMoney - _territoryPrice;
		_playerObject setVariable ["ExileLocker", _playerMoney, true];
	}
	else
	{
		_playerMoney = format["getLocker:%1", _playerUID] call ExileServer_system_database_query_selectSingleField;
		
		if (_playerMoney < _territoryPrice) then
		{
			throw [
				"",
				format["%1, you do not have enough poptabs in your locker, it costs **%2** and you have **%3**", _authorTag, _territoryPrice call ESM_fnc_scalarToString, _playerMoney call ESM_fnc_scalarToString]
			];
		};
		
		_playerMoney = _playerMoney - _territoryPrice;
	};
	
	format["updateLocker:%1:%2", _playerMoney, _playerUID] call ExileServer_system_database_query_fireAndForget;

	_flagObject setVariable ["ExileTerritoryLevel",_level + 1, true];
	_flagObject setVariable ["ExileTerritorySize",_territoryRange, true];

	format ["setTerritoryLevel:%1:%2", _level + 1, _flagID] call ExileServer_system_database_query_fireAndForget;
	format ["setTerritorySize:%1:%2", _territoryRange, _flagID] call ExileServer_system_database_query_fireAndForget;

	// Update all constructions and containers
	_flagObject call ExileServer_system_territory_updateNearContainers;
	_flagObject call ExileServer_system_territory_updateNearConstructions;

	if !(isNull(_playerObject)) then 
	{
		// Tell the client
		[
			_playerObject getVariable ["ExileSessionID", -1], 
			"toastRequest", 
			[
				"SuccessTitleAndText", 
				[
					"Territory upgraded!", 
					format ["Your territory has reached level %1 and now has a new radius of %2 meters.", _level + 1, _territoryRange]
				]
			]
		] call ExileServer_system_network_send_to;
	};

	// Let our user know
	[
		_commandID, 
		[
			["level", _level + 1],
			["range", _territoryRange],
			["cost", _territoryPrice],
			["locker", _playerMoney]
		]
	] 
	call ESM_fnc_respond;

	if (ESM_Logging_UpgradeTerritory) then
	{
		[
			"success", 
			"embed", 
			[
				"",
				format["%1 upgraded territory **%2**", _authorTag, _flagObject getVariable ["ExileTerritoryName", "N/A"]],
				[
					["Member UID", _playerUID],
					["Upgrade Cost", format["%1 poptabs", _territoryPrice call ESM_fnc_scalarToString], true],
					["Locker Total", format["%1 poptabs", _playerMoney call ESM_fnc_scalarToString], true],
					["Territory Name", _flagObject getVariable ["ExileTerritoryName", "N/A"], true],
					["Territory ID", _tid, true]
				]
			]
		]
		call ESM_fnc_logToDiscord;
	};
}
catch
{
	if !((_exception select 0) isEqualTo "") then 
	{
		["fn_upgradeTerritory", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_UpgradeTerritory) then 
		{
			["error", "message", [_exception select 0]] call ESM_fnc_logToDiscord;
		};
	};
	
	if !((_exception select 1) isEqualTo "") then 
	{
		[_commandID, [["error", _exception select 1]]] call ESM_fnc_respond;
	};
};

true