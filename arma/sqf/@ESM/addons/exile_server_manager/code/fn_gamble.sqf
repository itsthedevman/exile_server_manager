/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Gamble some poptabs! Nothing wrong in that... ;)
*/

params ["_commandID", "_authorInfo", "_playerUID", "_amountToGamble", "_userID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

private _amountGambled = 0;
private _lockerAfter = 0;
private _lockerBefore = 0;
private _package = [];
private _payoutRandomizer = [ESM_GamblePayoutRandomizerMin, ESM_GamblePayoutRandomizerMid, ESM_GamblePayoutRandomizerMax];
private _payoutPercentage = (ESM_GamblePayoutPercentage / 100);
private _winChance = (ESM_GambleWinPercentage / 100);

try 
{
	if !(format["isKnownAccount:%1", _playerUID] call ExileServer_system_database_query_selectSingleField) then 
	{
		throw ["", format["%1, you should try joining this server first.", _authorTag]];
	};

	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;

	if !(isNull _playerObject) then 
	{
		_lockerBefore = _playerObject getVariable ["ExileLocker", 0];
	}
	else
	{
		_lockerBefore = format["getLocker:%1", _playerUID] call ExileServer_system_database_query_selectSingleField;
	};

	switch (_amountToGamble) do 
	{
		case "all":
		{
			_amountGambled = _lockerBefore;
		};

		case "half":
		{
			_amountGambled = round(_lockerBefore / 2);
		};

		default 
		{
			_amountGambled = round(abs(parseNumber(_amountToGamble)));
		};
	};

	if (_amountGambled isEqualTo 0) then
	{
		throw ["", format["%1, you cannot gamble nothing", _authorTag]];	
	};

	if (_amountGambled > _lockerBefore) then 
	{
		throw ["", format["%1, you can't gamble more money than you have", _authorTag]];
	};

	if (_lockerBefore >= getNumber(missionConfigFile >> "CfgLocker" >> "maxDeposit")) then 
	{	
		throw ["", format["%1, your locker is full", _authorTag]];
	};

	// Above is a win
	if (random(1) > (1 - _winChance)) then 
	{
		_amountGambled = round(_amountGambled * (random(_payoutRandomizer) * _payoutPercentage + ESM_GamblePayoutModifier));

		_lockerAfter = _lockerBefore + _amountGambled;
		_package = [
			["type", "won"],
			["amount", _amountGambled],
			["locker_before", _lockerBefore],
			["locker_after", _lockerAfter]
		];

		if (_lockerAfter > getNumber(missionConfigFile >> "CfgLocker" >> "maxDeposit")) then 
		{
			_lockerAfter = getNumber(missionConfigFile >> "CfgLocker" >> "maxDeposit");
			_package pushBack ["maxed", true];
		};

		if !(isNull _playerObject) then 
		{
			_playerObject setVariable ["ExileLocker", _lockerAfter, true];
		};

		format["updateLocker:%1:%2", _lockerAfter, _playerUID] call ExileServer_system_database_query_fireAndForget;
	}
	else
	{
		if (_amountGambled > _lockerBefore) then 
		{
			throw ["", format["%1, you do not have enough money!", _authorTag]];
		};
		
		_lockerAfter = _lockerBefore - _amountGambled;

		if !(isNull _playerObject) then 
		{
			_playerObject setVariable ["ExileLocker", _lockerAfter, true];
		};

		format["updateLocker:%1:%2", _lockerAfter, _playerUID] call ExileServer_system_database_query_fireAndForget;

		_package = [
			["type", "loss"],
			["amount", _amountGambled],
			["locker_before", _lockerBefore],
			["locker_after", _lockerAfter]
		];
		_amountGambled = -_amountGambled;
	};

	[_commandID, _package] call ESM_fnc_respond;

	if (ESM_Logging_Gamble) then 
	{
		[
			"info", 
			"embed", 
			[
				"",
				format["%1 gambled some poptabs", _authorTag],
				[
					["Player UID", _playerUID, true],
					["Gamble Amount", _amountToGamble, true],
					["Amount won/loss", format["%1 poptabs", _amountGambled call ESM_fnc_scalarToString], true],
					["Player Locker Before", format["%1 poptabs", _lockerBefore call ESM_fnc_scalarToString], true],
					["Player Locker After", format["%1 poptabs", _lockerAfter call ESM_fnc_scalarToString], true]
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
		["fn_gamble", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_Gamble) then 
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