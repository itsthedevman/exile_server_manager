/* ----------------------------------------------------------------------------
Function:
	ESMs_command_demote

Description:
	Demotes a player from a moderator to a builder

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
private _loggingEnabled = ESM_Logging_DemotePlayer;
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

	// Confirm the target can be removed
	private _accessLevel = [_territory, _targetUID] call ExileClient_util_territory_getAccessLevel;
	switch (_accessLevel select 0) do
	{
		// Noop
		case const!(TERRITORY_ACCESS_MODERATOR): {};

		// Pfft
		case const!(TERRITORY_ACCESS_OWNER):
		{
			throw [["player", localize!("Demote_CannotDemoteOwner", _playerMention)]];
		};

		// No demoting plebs
		case const!(TERRITORY_ACCESS_BUILDER):
		{
			throw [["player", localize!("Demote_CannotDemoteBuilder", _playerMention)]];
		};

		// The player is smoking crack. The target isn't even a member of this territory
		default
		{
			throw [["player", localize!("Demote_CannotDemoteNothing", _playerMention)]];
		};
	};

	//////////////////////
	// Modification
	//////////////////////

	// 1 means builder
	[_territory, _targetUID, const!(TERRITORY_BUILDER_RIGHTS)] call ExileServer_system_territory_updateRights;

	//////////////////////
	// Completion
	//////////////////////
	[
		// Response
		[
			_id,
			[
				["author", localize!("ResponseAuthor", ESM_ServerID)],
				["title", localize!("Demote_Response_Title")],
				[
					"description",
					format[
						localize!("Demote_Response_Description"),
						_playerMention,
						_targetMention,
						_encodedTerritoryID
					]
				]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Demote_Log_Title")],
				["description", localize!("Demote_Log_Description")],
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
