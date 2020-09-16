/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Fires from a request when a player wants to pay a territory
*/

params ["_commandID", "_authorInfo", "_tid", "_flagID", "_playerUID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

try 
{
	private _flagObject = _flagID call ESM_fnc_getFlagObject;
	
	if (isNull _flagObject) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to pay territory protection for territory `ID:%3`, but the flag does not exist. This could be because they typed in the wrong ID or the territory has been deleted.", _authorTag, _playerUID, _tid], 
			format["%1, I am unable to find that territory. Please confirm you have typed in the territory ID in correctly and that you have not failed to make a protection payment.", _authorTag]
		];
	};

	if !([_flagObject, _playerUID] call ESM_fnc_hasAccessToTerritory) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to pay territory `ID:%3` protection, but they don't have permission. Awfully nice of them though", _authorTag, _playerUID, _tid], 
			format["%1, that's real kind of you, but you do not have access to this territory", _authorTag]
		];
	};
	
	private _flagStolen = _flagObject getVariable ["ExileFlagStolen", 0];
	
	if (_flagStolen isEqualTo 1) then
	{
		throw ["", format["%1, your flag has been stolen! You need to get it back before you can pay for protection", _authorTag]];
	};

	// Calculate required amounts
	private _territoryDatabaseID = _flagObject getVariable ["ExileDatabaseID", 0];
	private _radius = _flagObject getVariable ["ExileTerritorySize", 15];
	private _level = _flagObject getVariable ["ExileTerritoryLevel", 1];
	private _objectsInTerritory = _flagObject getVariable ["ExileTerritoryNumberOfConstructions", 0];

	// Calculate the amount of pop tabs required
	private _popTabAmountPerObject = getNumber (missionConfigFile >> "CfgTerritories" >> "popTabAmountPerObject");
	private _totalPopTabAmount = _level * _popTabAmountPerObject * _objectsInTerritory;

	// Add a tax
	private _tax = round(_totalPopTabAmount * ESM_PayTaxPercentage);
	_totalPopTabAmount = _totalPopTabAmount + _tax;

	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;
	private _playerMoney = 0;
	
	// The player is online
	if !(isNull(_playerObject)) then 
	{
		_playerMoney = _playerObject getVariable ["ExileLocker",0];
		
		if (_playerMoney < _totalPopTabAmount) then
		{
			throw [
				"",
				format["%1, you do not have enough poptabs in your locker, it costs **%2** and you have **%3**", _authorTag, _totalPopTabAmount call ESM_fnc_scalarToString, _playerMoney call ESM_fnc_scalarToString]
			];
		};

		_playerMoney = _playerMoney - _totalPopTabAmount;
		_playerObject setVariable ["ExileLocker", _playerMoney, true];
	}
	else
	{
		_playerMoney = format["getLocker:%1", _playerUID] call ExileServer_system_database_query_selectSingleField;
		
		if (_playerMoney < _totalPopTabAmount) then
		{
			throw [
				"", 
				format["%1, you do not have enough poptabs in your locker, it costs **%2** and you have **%3**", _authorTag, _totalPopTabAmount call ESM_fnc_scalarToString, _playerMoney call ESM_fnc_scalarToString]
			];
		};
		
		_playerMoney = _playerMoney - _totalPopTabAmount;
	};
	
	format["updateLocker:%1:%2", _playerMoney, _playerUID] call ExileServer_system_database_query_fireAndForget;

	// Extend the due date of the territory
	private _currentTimestamp = call ExileServer_util_time_currentTime;
	_flagObject setVariable ["ExileTerritoryLastPayed", _currentTimestamp];
	_flagObject call ExileServer_system_territory_maintenance_recalculateDueDate;
	
	// Save the due date in the database
	format["maintainTerritory:%1", _territoryDatabaseID] call ExileServer_system_database_query_fireAndForget;

	// Send a broadcast on the XM8
	_flagObject call ExileServer_system_xm8_sendProtectionMoneyPaid;

	// Respond to our command
	[
		_commandID, 
		[
			["payment", _totalPopTabAmount],
			["locker", _playerMoney]
		]
	] 
	call ESM_fnc_respond;

	// Increase the payment counter
	_territoryDatabaseID call ESM_fnc_incrementPaymentCounter;

	if (ESM_Logging_PayTerritory) then
	{
		[
			"success", 
			"embed", 
			[
				"",
				format["%1 paid territory **%2**'s protection money", _authorTag, _flagObject getVariable ["ExileTerritoryName", "N/A"]],
				[
					["Member UID", _playerUID],
					["Protection Cost", format["%1 poptabs", _totalPopTabAmount call ESM_fnc_scalarToString], true],
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
		["fn_payTerritory", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_PayTerritory) then 
		{
			["error", "message", [_exception select 0]] call ESM_fnc_logToDiscord;
		};
	};
	
	if !((_exception select 1) isEqualTo "") then 
	{
		[_commandID, [["error", _exception select 1]]] call ESM_fnc_respond;
	};
};