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

  // Make sure the player has joined this server
  if !(_playerUID call ESMs_util_account_isKnown) then
  {
    throw [
      ["player", localize!("AccountMissing", _playerMention, ESM_ServerID)]
    ];
  };

  // Ensure the territory flag exists in game
  if (isNull _territory) then
  {
    throw [
      ["admin", [
        ["description", localize!("Add_NullFlag_Admin")],
        ["fields", [
          [localize!("Territory"), _encodedTerritoryID],
          [localize!("Player"), _playerMetadata, true],
          [localize!("Target"), _targetMetadata, true]
        ]]
      ]],
      ["player", localize!("NullFlag", _playerMention, _encodedTerritoryID, ESM_ServerID)]
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

  // Ensure the player is at least a moderator
  // Territory admins bypass this
  if !([_playerUID, _territory, "moderator"] call ESMs_system_territory_checkAccess) then
  {
    throw [
      ["admin", [
        ["description", localize!("Add_MissingAccess_Admin")],
        ["fields", [
          [localize!("Territory"), _encodedTerritoryID],
          [localize!("Player"), _playerMetadata, true],
          [localize!("Target"), _targetMetadata, true]
        ]]
      ]],
      ["player", localize!("Add_MissingAccess", _playerMention, _encodedTerritoryID)]
    ];
  };

  // Data validation check to ensure no duplications
  private _currentBuildRights = _territory getVariable ["ExileTerritoryBuildRights", []];
  if (_targetUID in _currentBuildRights) then
  {
    throw [
      ["player", localize!("Add_ExistingRights", _playerMention)]
    ];
  };

  //////////////////////
  // Modification
  //////////////////////
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
        ["description", localize!("Add_Log_Description", _playerMention)],
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
