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

private _id = get!(_this, "id");

/*
	territory_id: Integer
	territory_database_id:
*/
private _data = get!(_this, "data");

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
private _metadata = get!(_this, "metadata");
if (isNil "_id" || { isNil "_data" || { isNil "_metadata" } }) exitWith { nil };

private _territoryData = get!(_data, "territory");
private _playerMetadata = get!(_metadata, "player");
private _targetMetadata = get!(_metadata, "target");

private _encodedTerritoryID = get!(_territoryData, "id");
private _territoryDatabaseID = get!(_territoryData, "database_id");
private _playerUID = get!(_playerMetadata, "steam_uid");
private _playerMention = get!(_playerMetadata, "discord_mention");
private _targetUID = get!(_targetMetadata, "steam_uid");
private _targetMention = get!(_targetMetadata, "discord_mention");

try
{
	private _territory = _territoryDatabaseID call ESMs_object_flag_get;

	if (isNull _territory) then
	{
		throw [
			["admin", localize!("Add_NullFlag_Admin", _playerMention, _playerUID, _targetUID, _encodedTerritoryID)],
			["player", localize!("NullFlag", _playerMention)]
		];
	};

	if !([_playerUID, _territory, "moderator"] call ESMs_system_territory_checkAccess) then
	{
		throw [
			["admin", localize!("Add_MissingAccess_Admin", _playerMention, _playerUID, _encodedTerritoryID)],
			["player", localize!("Add_MissingAccess", _playerMention, _encodedTerritoryID)]
		];
	};

	private _ownerUID = _territory getVariable ["ExileOwnerUID", ""];

	// Ensure they cannot add themselves. Territory admins are exempt
	if (_playerUID isEqualTo _targetUID && !(_playerUID in ESM_TerritoryAdminUIDs)) then
	{
		throw [
			["admin", localize!("Add_InvalidAdd_Admin", _playerMention, _playerUID, _encodedTerritoryID)],
			["player", localize!("Add_InvalidAdd", _playerMention)]
		];
	};

	// If the guy we want to add is the owner, skip here since he has already uber rights
	if (_ownerUID isEqualTo _targetUID) then
	{
		throw [
			["player", localize!("Add_InvalidAdd_Owner", _playerMention)]
		];
	};

	// Get the current rights
	private _currentBuildRights = _territory getVariable ["ExileTerritoryBuildRights", []];

	// Do not add em twice to the build rights
	if (_targetUID in _currentBuildRights) then
	{
		throw [
			["player", localize!("Add_InvalidAdd_Exists", _playerMention)]
		];
	};

	// Add the build rights to the flag pole and update it
	_currentBuildRights pushBack _targetUID;
	_territory setVariable ["ExileTerritoryBuildRights", _currentBuildRights, true];

	// Update the build rights in the database
	(format [
		"updateTerritoryBuildRights:%1:%2", _currentBuildRights, _territoryDatabaseID
	]) call ExileServer_system_database_query_fireAndForget;

	// Respond back to our command
	[
		// Response
		[_id],

		// Log the following?
		ESM_Logging_AddPlayerToTerritory,

		// Log embed
		[
			["title", localize!("Success")],
			["description", localize!("Add_Log_Description", _playerMention)],
			["color", "green"],
			["fields", [
				[localize!("Territory"), [
					["id", _encodedTerritoryID],
					["name", _territory getVariable ["ExileTerritoryName", "N/A"]]
				]],
				[localize!("Player"), _playerMetadata],
				[localize!("Target"), _targetMetadata]
			]]
		]
	]
	call ESMs_util_command_handleSuccess;
}
catch
{
	[_id, _exception, file_name!(), ESM_Logging_AddPlayerToTerritory] call ESMs_util_command_handleException;
};

nil
