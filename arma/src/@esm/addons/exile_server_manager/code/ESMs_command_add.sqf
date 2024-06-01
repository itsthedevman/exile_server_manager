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
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _id = get!(_this, "id");

/*
	territory_id: String
	territory_database_id: Integer
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

//////////////////////
// Initialization
//////////////////////
private _loggingEnabled = ESM_Logging_AddPlayerToTerritory;
private _encodedTerritoryID = get!(_data, "territory_id");
private _territoryDatabaseID = get!(_data, "territory_database_id");

private _playerMetadata = get!(_metadata, "player");
private _targetMetadata = get!(_metadata, "target");

private _playerUID = get!(_playerMetadata, "steam_uid");
private _playerMention = get!(_playerMetadata, "discord_mention");
private _targetUID = get!(_targetMetadata, "steam_uid");

private _territory = _territoryDatabaseID call ESMs_system_territory_get;

try
{
	//////////////////////
	// Validation
	//////////////////////

	// Ensure the territory flag exists in game
	if (isNull _territory) then
	{
		throw [
			["admin", [
				["description", localize!("NullFlag_Admin", file_name!())],
				["fields", [
					[localize!("Territory"), _encodedTerritoryID],
					[localize!("Player"), _playerMetadata, true],
					[localize!("Target"), _targetMetadata, true]
				]]
			]],
			["player", localize!("NullFlag", _playerMention, _encodedTerritoryID, ESM_ServerID)]
		];
	};

	// Ensure the player has joined the server at least once
	if !(_playerUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("PlayerNeedsToJoin", _playerMention, ESM_ServerID)]
		];
	};

	// Ensure the target player has joined the server at least once
	if !(_targetUID call ESMs_system_account_isKnown) then
	{
		// This can be executed on a player that is not registered with ESM
		private _targetMention = get!(_targetMetadata, "discord_mention");
		if (nil?(_targetMention) || { empty?(_targetMention) }) then
		{
			_targetMention = _targetUID;
		};

		throw [
			["player", localize!("TargetNeedsToJoin", _playerMention, _targetMention, ESM_ServerID)]
		];
	};

	// Ensure the player is at least a moderator
	// Territory admins bypass this
	if !([_territory, _playerUID, "moderator"] call ESMs_system_territory_checkAccess) then
	{
		throw [
			["admin", [
				["description", localize!("MissingTerritoryAccess_Admin")],
				["fields", [
					[localize!("Function"), file_name!()],
					[localize!("Territory"), _encodedTerritoryID],
					[localize!("Player"), _playerMetadata, true],
					[localize!("Target"), _targetMetadata, true]
				]]
			]],
			["player", localize!("MissingTerritoryAccess", _playerMention, _encodedTerritoryID)]
		];
	};

	// Ensure the player isn't trying to add themselves
	// Territory admins bypass this
	if (_playerUID isEqualTo _targetUID && !(_playerUID in ESM_TerritoryAdminUIDs)) then
	{
		throw [
			["admin", [
				["description", localize!("Add_InvalidAdd_Admin")],
				["fields", [
					[localize!("Territory"), _encodedTerritoryID],
					[localize!("Player"), _playerMetadata, true],
					[localize!("Target"), _targetMetadata, true]
				]]
			]],
			["player", localize!("Add_InvalidAdd", _playerMention)]
		];
	};

	// Confirm the target can be added
	// 0 means they are not a member of the territory
	private _accessLevel = [_territory, _targetUID] call ExileClient_util_territory_getAccessLevel;
	if !((_accessLevel select 0) isEqualTo const!(TERRITORY_ACCESS_NONE)) then
	{
		throw [["player", localize!("Add_ExistingRights", _playerMention)]];
	};

	//////////////////////
	// Modification
	//////////////////////
	private _currentBuildRights = _territory getVariable ["ExileTerritoryBuildRights", []];
	_currentBuildRights pushBack _targetUID;

	_territory setVariable ["ExileTerritoryBuildRights", _currentBuildRights, true];

	private _updateQuery = format [
		"updateTerritoryBuildRights:%1:%2", _currentBuildRights, _territoryDatabaseID
	];

	_updateQuery call ExileServer_system_database_query_fireAndForget;

	//////////////////////
	// Completion
	//////////////////////
	[
		// Response
		[_id],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Add_Log_Title")],
				["description", localize!("Add_Log_Description")],
				["color", "green"],
				["fields", [
					[localize!("Territory"), [
						["id", _encodedTerritoryID],
						["name", _territory getVariable ["ExileTerritoryName", "N/A"]]
					]],
					[localize!("Player"), _playerMetadata, true],
					[localize!("Target"), _targetMetadata, true]
				]]
			]
		}
	]
	call ESMs_util_command_handleSuccess;
}
catch
{
	[_id, _exception, file_name!(), _loggingEnabled] call ESMs_util_command_handleFailure;
};

nil
