/* ----------------------------------------------------------------------------
Function:
	ESMs_command_remove

Description:
	Removes a player from a territory

Parameters:
	_this - [HashMap] Message object

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
private _loggingEnabled = ESM_Logging_RemovePlayerFromTerritory;

private _encodedTerritoryID = get!(_data, "territory_id");
private _territoryDatabaseID = get!(_data, "territory_database_id");

private _playerMetadata = get!(_metadata, "player");
private _targetMetadata = get!(_metadata, "target");

private _playerUID = get!(_playerMetadata, "steam_uid");
private _targetUID = get!(_targetMetadata, "steam_uid");

private _playerMention = get!(_playerMetadata, "discord_mention");
private _targetMention = get!(_targetMetadata, "discord_mention");

private _territory = _territoryDatabaseID call ESMs_system_territory_get;

try
{
	//////////////////////
	// Validation
	//////////////////////

	// Territory flag must exist in game
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

	// Player must have joined the server at least once
	if !(_playerUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("PlayerNeedsToJoin", _playerMention, ESM_ServerID)]
		];
	};

	// Target player must have joined the server at least once
	if !(_targetUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("TargetNeedsToJoin", _playerMention, _targetMention, ESM_ServerID)]
		];
	};

	private _selfRemoval = _playerUID isEqualTo _targetUID;

	// If the player is removing themselves, we only need to check builder permission
	// which also doubles as a player membership check.
	// Otherwise, the player must be a moderator
	private _basePermissionLevel = ["moderator", "builder"] select _selfRemoval;

	// Player must have base permission in order to remove the target player or themselves
	if !([_territory, _playerUID, _basePermissionLevel] call ESMs_system_territory_checkAccess) then
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

	// If the player isn't removing themselves, ensure the target is valid
	if (!_selfRemoval) then
	{
		private _accessLevel = [_territory, _targetUID] call ExileClient_util_territory_getAccessLevel;
		switch (_accessLevel select 0) do
		{
			// Noop
			case const!(TERRITORY_ACCESS_BUILDER);
			case const!(TERRITORY_ACCESS_MODERATOR): {};

			// Pfft
			case const!(TERRITORY_ACCESS_OWNER):
			{
				throw [["player", localize!("Remove_CannotRemoveOwner", _playerMention)]];
			};

			// The player is smoking crack. The target isn't even a member of this territory
			default
			{
				throw [["player", localize!("Remove_CannotRemoveNothing", _playerMention)]];
			};
		};
	};

	//////////////////////
	// Modification
	//////////////////////
	private _moderators = _territory getVariable ["ExileTerritoryModerators", []];
	private _buildRights = _territory getVariable ["ExileTerritoryBuildRights", []];

	_moderators = _moderators - [_targetUID];
	_buildRights = _buildRights - [_targetUID];

	_territory setVariable ["ExileTerritoryModerators", _moderators, true];
	_territory setVariable ["ExileTerritoryBuildRights", _buildRights, true];

	// Update the build rights / moderators in the database, right meow!
	format
	[
		"updateTerritoryModerators:%1:%2",
		_moderators,
		_territoryDatabaseID
	]
	call ExileServer_system_database_query_fireAndForget;

	format
	[
		"updateTerritoryBuildRights:%1:%2",
		_buildRights,
		_territoryDatabaseID
	]
	call ExileServer_system_database_query_fireAndForget;

	//////////////////////
	// Completion
	//////////////////////
	[
		// Response
		[
			_id,
			[
				["author", localize!("ResponseAuthor", ESM_ServerID)],
				["title", localize!("Remove_Response_Title", _encodedTerritoryID)],
				[
					"description",
					localize!("Remove_Response_Description", _playerMention, _targetUID)
				]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Remove_Log_Title")],
				["description", localize!("Remove_Log_Description")],
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

true
