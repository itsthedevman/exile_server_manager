/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Add a player to the territory pls
*/
params ["_commandID", "_authorInfo", "_tid", "_flagID", "_targetUID", "_playerUID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

try
{
	private _flagObject = _flagID call ESM_fnc_getFlagObject;

	if (isNull _flagObject) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to add `UID:%3` to territory `ID:%4`, but the flag does not exist. This could be because they typed in the wrong ID or the territory has been deleted.", _authorTag, _playerUID, _targetUID, _tid],
			format["%1, I am unable to find that territory. Please confirm you have typed in the territory ID in correctly and that you have not failed to make a protection payment.", _authorTag]
		];
	};

	// Don't allow adding people who aren't part of this server (also catches discord id mistakes. ;))
	if !(format["isKnownAccount:%1", _targetUID] call ExileServer_system_database_query_selectSingleField) then
	{
		throw ["", format["%1, `%2` has not joined this server", _authorTag, _targetUID]];
	};

	if !([_flagObject, _playerUID, "moderator"] call ESM_fnc_hasAccessToTerritory) then
	{
		throw [
			format["%1 (`UID:%2`) attempted to add `UID:%3` to territory `ID:%4`, but they don't have permission!", _authorTag, _playerUID, _targetUID, _tid],
			format["%1, you do not have permission to add people to this territory.", _authorTag]
		];
	};

	// get the owners uid
	private _ownerUID = _flagObject getVariable ["ExileOwnerUID", ""];

	// One cannot add herself/himself
	if (_playerUID isEqualTo _targetUID && !(_playerUID in ESM_TerritoryManagementUIDs)) then
	{
		throw [
			format["%1 (`UID:%2`) tried to add themselves to territory `ID:%3`. Time to go laugh at them!", _authorTag, _playerUID, _tid],
			format["%1, you cannot add yourself to this territory", _authorTag]
		];
	};

	// If the guy we wants to add is the owner, skip here since he has already uber rights
	if (_ownerUID isEqualTo _targetUID) then
	{
		throw ["", format["%1, you are the owner of this territory, you are already part of this territory, silly", _authorTag]];
	};

	// Get the current rights
	private _currentBuildRights = _flagObject getVariable ["ExileTerritoryBuildRights", []];

	// Do not add em twice to the build rights
	if (_targetUID in _currentBuildRights) then
	{
		throw ["", format["%1, this player already has build rights", _authorTag]];
	};

	// Add the build rights to the flag pole
	_currentBuildRights pushBack _targetUID;

	// Update the build rights in the flag pole
	_flagObject setVariable ["ExileTerritoryBuildRights", _currentBuildRights, true];

	// Update the build rights in the database (NOW!)
	format["updateTerritoryBuildRights:%1:%2", _currentBuildRights, _flagID] call ExileServer_system_database_query_fireAndForget;

	// Respond back to our command
	[_commandID] call ESM_fnc_respond;

	if (ESM_Logging_AddPlayerToTerritory) then
	{
		// Let our logging channel know..
		[
			"success",
			"embed",
			[
				"",
				format["%1 added a player to territory **%2**", _authorTag, _flagObject getVariable ["ExileTerritoryName", "N/A"]],
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
		["fn_addPlayerToTerritory", _exception select 0] call ESM_fnc_log;

		if (ESM_Logging_AddPlayerToTerritory) then
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
