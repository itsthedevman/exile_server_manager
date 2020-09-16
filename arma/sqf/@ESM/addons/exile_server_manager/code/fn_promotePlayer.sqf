/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Demotes a player from Moderator
*/
params ["_commandID", "_authorInfo", "_tid", "_flagID", "_targetUID", "_playerUID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

try
{
	// Get the flag object
	private _flagObject = _flagID call ESM_fnc_getFlagObject;

	// Make sure we found it
	if (isNull(_flagObject)) then 
	{
		throw [
			format["%1 (`UID:%2`) attempted to promote `UID:%3` to territory `ID:%4`, but the flag does not exist. This could be because they typed in the wrong ID or the territory has been deleted.", _authorTag, _playerUID, _targetUID, _tid], 
			format["%1, I am unable to find that territory. Please confirm you have typed in the territory ID in correctly and that you have not failed to make a protection payment.", _authorTag]
		];
	};
	
	// Don't allow adding people who aren't part of this server (also catches discord id mistakes. ;))
	if !(format["isKnownAccount:%1", _targetUID] call ExileServer_system_database_query_selectSingleField) then 
	{
		throw ["", format["%1, `%2` has not joined this server", _authorTag, _targetUID]];
	};
	
	if !([_flagObject, _playerUID, "owner"] call ESM_fnc_hasAccessToTerritory) then 
	{
		throw [
			format["%1 (`UID:%2`) attempted to promote `UID:%3` to territory `ID:%4`, but they don't have permission!", _authorTag, _playerUID, _targetUID, _tid], 
			format["%1, you do not have permission to promote members", _authorTag]
		];
	};
	
	// Check if they are a part of the territory first
	if !([_flagObject, _targetUID] call ESM_fnc_hasAccessToTerritory) then 
	{
		throw ["", format["%1, you must add this person to your territory first before you can promote them", _authorTag]];
	};

	if (_playerUID isEqualTo _targetUID && !(_playerUID in ESM_TerritoryManagementUIDs)) then 
	{
		throw [
			format["%1 (`UID:%2`) tried to promote themselves to moderator in territory `ID:%3`", _authorTag, _playerUID, _tid], 
			format["%1, you cannot promote yourself", _authorTag]
		];
	};

	// Check if the player is already a mod
	if (!(_targetUID in ESM_TerritoryManagementUIDs) && {[_flagObject, _targetUID, "moderator"] call ESM_fnc_hasAccessToTerritory}) then 
	{
		throw ["", format["%1, this player is already a moderator", _authorTag]];
	};

	// Update the flag rights (luckily, Exile already contains such a function)
	// Member: 1, Moderator: 2
	[_flagObject, _targetUID, 2] call ExileServer_system_territory_updateRights;
	
	// Check if it actually worked
	if !([_flagObject, _targetUID, "moderator"] call ESM_fnc_hasAccessToTerritory) then 
	{
		throw [
			format["[ERROR] %1 (`UID:%2`) tried to promote `UID:%3` to moderator in territory `ID:%4`, but it failed.", _authorTag, _playerUID, _targetUID, _tid], 
			format["%1, I failed to promote `%2` to moderator. Please contact a server admin and let them know!", _authorTag, _targetUID]
		];
	};
	
	[_commandID] call ESM_fnc_respond;
	
	// Let our logging channel know..
	if (ESM_Logging_PromotePlayer) then 
	{
		[
			"success", 
			"embed", 
			[
				"",
				format["%1 promoted a player in territory **%2**", _authorTag, _flagObject getVariable ["ExileTerritoryName", "N/A"]],
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
		["fn_promotePlayer", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_PromotePlayer) then 
		{
			["error", "message", [_exception select 0]] call ESM_fnc_logToDiscord;
		};
	};
	
	if !((_exception select 1) isEqualTo "") then 
	{
		[_commandID, [["error", _exception select 1]]] call ESM_fnc_respond;
	};
};
