/* ----------------------------------------------------------------------------
Function:
	ESMs_command_add

Description:
	Adds a player to a territory
	Called from ESMs_system_extension_callback as part of a command workflow.
	Do not call manually unless you know what you're doing!

Parameters:
	_this - [Hashmap] A hashmap representation of a ESM message

Returns:
	Nothing

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2023 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _id = dig!(_this, "id");

/*
	territory_id: Integer
*/
private _data = dig!(_this, "data");

/*
	player: HashMap
		steam_uid: String,
		discord_id: String,
		discord_name: String,
		discord_mention: String,
	target: HashMap | Nothing
		steam_uid: String,
		discord_id: String,
		discord_name: String,
		discord_mention: String,
*/
private _metadata = dig!(_this, "metadata");
if (isNil "_id" || { isNil "_data" || { isNil "_metadata" } }) exitWith { nil };

private _territoryID = get!(_data, "territory_id");
private _playerUID = dig!(_metadata, "player", "steam_uid");
private _playerMention = dig!(_metadata, "player", "discord_mention");
private _targetUID = dig!(_metadata, "target", "steam_uid");
private _targetMention = dig!(_metadata, "target", "discord_mention");

try
{
	private _flagObject = _territoryID call ESMs_object_flag_get;

	if (isNull _flagObject) then
	{
		throw [
			[
				"admin",
				format[localize "$STR_ESM_Add_NullFlag_Admin", _playerMention, _playerUID, _targetUID, _territoryID]
			],
			["player", format[localize "$STR_ESM_NullFlag", _playerMention]]
		];
	};

	if !([_playerUID, _flagObject, "moderator"] call ESMs_system_territory_checkAccess) then
	{
		throw [
			format[localize "$STR_ESM_Add_MissingAccess_Admin", _playerMention, _playerUID, _territoryID],
			format[localize "$STR_ESM_Add_MissingAccess", _playerMention]
		];
	};

	private _ownerUID = _flagObject getVariable ["ExileOwnerUID", ""];

	// Ensure they cannot add themselves. Territory admins are exempt
	if (_playerUID isEqualTo _targetUID && !(_playerUID in ESM_TerritoryAdminUIDs)) then
	{
		throw [
			format["%1 (`UID:%2`) tried to add themselves to territory `ID:%3`. Time to go laugh at them!", _authorTag, _playerUID, _territoryID],
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
	[_id] call ESMs_system_message_respond_to;

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
					["Territory ID", _territoryID, true]
				]
			]
		]
		call ESM_fnc_logToDiscord;
	};
}
catch
{
	[_id, _exception, "ESMs_command_add", ESM_Logging_AddPlayerToTerritory] call ESMs_util_command_handleException;
};

nil
