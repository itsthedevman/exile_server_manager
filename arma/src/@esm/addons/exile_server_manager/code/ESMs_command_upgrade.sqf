/* ----------------------------------------------------------------------------
Function:
	ESMs_command_upgrade

Description:
	Upgrades a territory

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
*/
private _metadata = get!(_this, "metadata");
if (isNil "_id" || { isNil "_data" || { isNil "_metadata" } }) exitWith { nil };

//////////////////////
// Initialization
//////////////////////
private _loggingEnabled = ESM_Logging_UpgradeTerritory;
private _encodedTerritoryID = get!(_data, "territory_id");
private _territoryDatabaseID = get!(_data, "territory_database_id");

private _playerMetadata = get!(_metadata, "player");
private _playerUID = get!(_playerMetadata, "steam_uid");
private _playerMention = get!(_playerMetadata, "discord_mention");

private _territory = _territoryDatabaseID call ESMs_system_territory_get;

try
{
	//////////////////////
	// Validation
	//////////////////////
	// Ensure the player has joined the server at least once
	if !(_playerUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("PlayerNeedsToJoin", _playerMention, ESM_ServerID)]
		];
	};

	// Ensure the territory exists
	if (isNull _territory) then
	{
		throw [
			["admin", [
				["description", localize!("NullFlag_Admin", file_name!())],
				["fields", [
					[localize!("Territory"), _encodedTerritoryID],
					[localize!("Player"), _playerMetadata, true]
				]]
			]],
			["player", localize!("NullFlag", _playerMention, _encodedTerritoryID, ESM_ServerID)]
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
					[localize!("Player"), _playerMetadata, true]
				]]
			]],
			["player", localize!("MissingTerritoryAccess", _playerMention, _encodedTerritoryID)]
		];
	};

	// Flag stolen check
	// 1 means stolen
	private _flagStolen = _territory getVariable ["ExileFlagStolen", const!(FLAG_OK)];
	if (_flagStolen isEqualTo const!(FLAG_STOLEN)) then
	{
		throw [["player", localize!("Upgrade_StolenFlag", _playerMention, _encodedTerritoryID)]];
	};

	// Max level check
	private _currentLevel = _territory getVariable ["ExileTerritoryLevel", 0];
	private _upgradeListings = getArray(missionConfigFile >> "CfgTerritories" >> "Prices");
	private _maxLevel = count _upgradeListings;
	private _nextLevel = _currentLevel + 1;

	if (_nextLevel > _maxLevel) then
	{
		throw [["player", localize!("Upgrade_MaxLevel", _playerMention, _encodedTerritoryID)]];
	};

	// Gather the upgrade information
	private _territoryPrice = (_upgradeListings select _currentLevel) select 0;
	private _territoryRange = (_upgradeListings select _currentLevel) select 1;

	// Calculate a payment tax. 0% will be 0
	private _tax = round(_territoryPrice * ESM_Taxes_TerritoryUpgrade);
	_territoryPrice = _territoryPrice + _tax;

	//////////////////////
	// Modification
	//////////////////////

	// If the player is online make sure to adjust their in-game data
	// Otherwise, we'll get their poptabs from the database itself
	private _playerMoney = 0;
	private _updatedPlayerMoney = 0;
	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;

	if (null?(_playerObject)) then // Because Arma!
	{
		debug!("Nil player");
		// Locker check
		_playerMoney = format["getLocker:%1", _playerUID] call ExileServer_system_database_query_selectSingleField;
		if (_playerMoney < _territoryPrice) then
		{
			throw [[
				"player",
				localize!("Upgrade_TooPoor", _playerMention, _territoryPrice call ESMs_util_number_toString, _playerMoney call ESMs_util_number_toString)
			]];
		};

		_updatedPlayerMoney = _playerMoney - _territoryPrice;
	}
	else
	{
		debug!("Not nil player");
		// Locker check
		_playerMoney = _playerObject getVariable ["ExileLocker", 0];
		if (_playerMoney < _territoryPrice) then
		{
			throw [[
				"player",
				localize!("Upgrade_TooPoor", _playerMention, _territoryPrice call ESMs_util_number_toString, _playerMoney call ESMs_util_number_toString)
			]];
		};

		// Adjust the players attributes and globally update
		_updatedPlayerMoney = _playerMoney - _territoryPrice;
		_playerObject setVariable ["ExileLocker", _updatedPlayerMoney, true];
	};

	format["updateLocker:%1:%2", _updatedPlayerMoney, _playerUID] call ExileServer_system_database_query_fireAndForget;

	_territory setVariable ["ExileTerritoryLevel", _nextLevel, true];
	_territory setVariable ["ExileTerritorySize", _territoryRange, true];

	format["setTerritoryLevel:%1:%2", _nextLevel, _territoryDatabaseID] call ExileServer_system_database_query_fireAndForget;
	format["setTerritorySize:%1:%2", _territoryRange, _territoryDatabaseID] call ExileServer_system_database_query_fireAndForget;

	// Update all constructions and containers
	_territory call ExileServer_system_territory_updateNearContainers;
	_territory call ExileServer_system_territory_updateNearConstructions;

	//////////////////////
	// Completion
	//////////////////////
	// Tell the client
	if !(isNull(_playerObject)) then
	{
		[
			_playerObject getVariable ["ExileSessionID", -1],
			"toastRequest",
			[
				"SuccessTitleAndText",
				[
					"Territory upgraded!",
					format ["Your territory has reached level %1 and now has a new radius of %2 meters.", _nextLevel, _territoryRange]
				]
			]
		]
		call ExileServer_system_network_send_to;
	};

	// Respond to ESM and log if needed
	[
		// Response
		[
			_id,
			[
				["level", _nextLevel],
				["range", _territoryRange],
				["cost", _territoryPrice],
				["locker", _updatedPlayerMoney]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Upgrade_Log_Title")],
				["description", localize!("Upgrade_Log_Description")],
				["color", "green"],
				[
					"fields",
					[
						[
							localize!("Receipt"),
							[
								[
									"Locker before",
									format ["+%1 poptabs", _playerMoney call ESMs_util_number_toString]
								],
								[
									localize!("Upgrade_Log_TotalCost_Title"),
									localize!("Upgrade_Log_TotalCost_Description", _territoryPrice)
								],
								[
									"Locker after",
									format ["+%1 poptabs", _updatedPlayerMoney call ESMs_util_number_toString]
								]
							]
						],
						[
							localize!("Territory"),
							[
								["id", _encodedTerritoryID],
								["name", _territory getVariable ["ExileTerritoryName", "N/A"]]
							]
						],
						[localize!("Player"), _playerMetadata, true]
					]
				]
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
