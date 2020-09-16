/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Remove a player from the territory pls
*/
params ["_commandID", "_authorInfo", "_tid", "_flagID", "_targetUID", "_playerUID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

try 
{
	private _flagObject = _flagID call ESM_fnc_getFlagObject;

	if (isNull _flagObject) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to remove `UID:%3` from territory `ID:%4`, but the flag does not exist. This could be because they typed in the wrong ID or the territory has been deleted.", _authorTag, _playerUID, _targetUID, _tid], 
			format["%1, I am unable to find that territory. Please confirm you have typed in the territory ID in correctly and that you have not failed to make a protection payment.", _authorTag]
		];
	};
	
	// Don't allow adding people who aren't part of this server (also catches discord id mistakes. ;))
	if !(format["isKnownAccount:%1", _targetUID] call ExileServer_system_database_query_selectSingleField) then 
	{
		throw ["", format["%1, `%2` has not joined this server", _authorTag, _targetUID]];
	};

	// We are trying to remove ourselves
	if (_targetUID isEqualTo _playerUID) then 
	{
		if !([_flagObject, _playerUID] call ESM_fnc_hasAccessToTerritory) then 
		{
			throw [
				format["%1 (`UID:%2`) attempted to remove themselves from territory `ID:%3`, but they aren't a part of that territory", _authorTag, _playerUID, _tid], 
				format["%1, you aren't a member of this territory", _authorTag]
			];
		};
	}
	else
	{
		if !([_flagObject, _playerUID, "moderator"] call ESM_fnc_hasAccessToTerritory) then 
		{
			throw [
				format["%1 (`UID:%2`) attempted to remove `UID:%3` from territory `ID:%4`, but they don't have permission", _authorTag, _playerUID, _targetUID, _tid], 
				format["%1, you do not have permission to remove people from this territory.", _authorTag]
			];
		};
	};

	// get the owners uid
	private _ownerUID = _flagObject getVariable ["ExileOwnerUID", ""];
	if (_targetUID isEqualTo _ownerUID) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to remove the owner, `UID:%3`, from territory `ID:%4`", _authorTag, _playerUID, _targetUID, _tid], 
			format["%1, owners cannot be removed from their territory", _authorTag]
		];
	};

	private _moderators = _flagObject getVariable ["ExileTerritoryModerators", []];
	private _buildRights = _flagObject getVariable ["ExileTerritoryBuildRights", []];

	_moderators = _moderators - [_targetUID];
	_buildRights = _buildRights - [_targetUID];
	
	// Update the build rights in the flag pole
	_flagObject setVariable ["ExileTerritoryModerators", _moderators, true];
	_flagObject setVariable ["ExileTerritoryBuildRights", _buildRights, true];

	// Update the build rights / Moderators in the database (NOW!)
	format["updateTerritoryBuildRights:%1:%2", _buildRights, _flagID] call ExileServer_system_database_query_fireAndForget;
	format["updateTerritoryModerators:%1:%2", _moderators, _flagID] call ExileServer_system_database_query_fireAndForget;
	
	// Let the player know in discord
	[_commandID] call ESM_fnc_respond;
	
	if (ESM_Logging_RemovePlayerFromTerritory) then 
	{
		// Let our logging channel know..
		[
			"success", 
			"embed", 
			[
				"",
				format["%1 remove a player from territory **%2**", _authorTag, _flagObject getVariable ["ExileTerritoryName", "N/A"]],
				[
					["Member UID", _playerUID, true],
					["Target UID", _targetUID, true],
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
		["fn_removePlayerFromTerritory", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_RemovePlayerFromTerritory) then 
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