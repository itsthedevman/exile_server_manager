/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Transfer some poptabs from one player to another
*/

params ["_commandID", "_authorInfo", "_playerUID", "_targetUID", "_amountToTransfer"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

private _playerLockerBefore = 0;
private _targetLockerBefore = 0;
private _playerLocker = 0;
private _targetLocker = 0;
_amountToTransfer = parseNumber(_amountToTransfer);
try 
{
	if !(format["isKnownAccount:%1", _playerUID] call ExileServer_system_database_query_selectSingleField) then 
	{
		throw ["", format["%1, you should try joining this server first.", _authorTag]];
	};

	if !(format["isKnownAccount:%1", _targetUID] call ExileServer_system_database_query_selectSingleField) then 
	{
		throw ["", format["%1, they should try joining this server first.", _authorTag]];
	};
	
	if (_playerUID isEqualTo _targetUID) then 
	{
		throw ["", format["%1, you cannot give yourself poptabs", _authorTag]];
	};

	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;
	private _targetObject = _targetUID call ExileClient_util_player_objectFromPlayerUID;

	if !(isNull _playerObject) then 
	{
		_playerLocker = _playerObject getVariable ["ExileLocker", 0];
	}
	else
	{
		_playerLocker = format["getLocker:%1", _playerUID] call ExileServer_system_database_query_selectSingleField;
	};

	if !(isNull _targetObject) then 
	{
		_targetLocker = _targetObject getVariable ["ExileLocker", 0];
	}
	else
	{
		_targetLocker = format["getLocker:%1", _targetUID] call ExileServer_system_database_query_selectSingleField;
	};

	if (_amountToTransfer > _playerLocker) then 
	{
		throw ["", format["%1, you can't transfer more money than you have", _authorTag]];
	};

	if (_targetLocker >= getNumber(missionConfigFile >> "CfgLocker" >> "maxDeposit")) then 
	{	
		throw ["", format["%1, their locker is full", _authorTag]];
	};

	_playerLockerBefore = _playerLocker;
	_targetLockerBefore = _targetLocker;

	_playerLocker = _playerLocker - _amountToTransfer;
	_targetLocker = _targetLocker + _amountToTransfer;

	if !(isNull _playerObject) then 
	{
		_playerObject setVariable ["ExileLocker", _playerLocker, true];
		format["updateLocker:%1:%2", _playerLocker, _playerUID] call ExileServer_system_database_query_fireAndForget;
	}
	else
	{
		format["updateLocker:%1:%2", _playerLocker, _playerUID] call ExileServer_system_database_query_fireAndForget;
	};

	if !(isNull _targetObject) then 
	{
		_targetObject setVariable ["ExileLocker", _targetLocker, true];
		
		[
			_targetObject, 
			"toastRequest", 
			[
				"SuccessTitleAndText", 
				["Transfer Completed!", format["%1 has been deposited in your locker", _amountToTransfer]]
			]
		] call ExileServer_system_network_send_to;
		
		format["updateLocker:%1:%2", _targetLocker, _targetUID] call ExileServer_system_database_query_fireAndForget;
	}
	else
	{
		format["updateLocker:%1:%2", _targetLocker, _targetUID] call ExileServer_system_database_query_fireAndForget;
	};

	[_commandID, [["locker", _playerLocker]]] call ESM_fnc_respond;

	if (ESM_Logging_TransferPoptabs) then 
	{
		[
			"info", 
			"embed", 
			[
				"",
				format["%1 transferred some poptabs", _authorTag],
				[
					["Player UID", _playerUID, true],
					["Transfer Amount", _amountToTransfer, true],
					["Target UID", _targetUID, true],
					["Player Locker Before", format["%1 poptabs", _playerLockerBefore call ESM_fnc_scalarToString], true],
					["Player Locker After", format["%1 poptabs", _playerLocker call ESM_fnc_scalarToString], true],
					["Target Locker Before", format["%1 poptabs", _targetLockerBefore call ESM_fnc_scalarToString], true],
					["Target Locker After", format["%1 poptabs", _targetLocker call ESM_fnc_scalarToString], true]
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
		["fn_transferPoptabs", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_TransferPoptabs) then 
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