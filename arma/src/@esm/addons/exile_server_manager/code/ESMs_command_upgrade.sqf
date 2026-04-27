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
private _loggingEnabled = ESM_Logging_CommandUpgrade;
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

	// Territory flag must exist in game
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

	// Player must have joined the server at least once
	if !(_playerUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("PlayerNeedsToJoin", _playerMention, ESM_ServerID)]
		];
	};

	// Player must have moderator permissions
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

	// Territory flag must not be stolen
	// 1 means stolen
	private _flagStolen = _territory getVariable ["ExileFlagStolen", const!(FLAG_OK)];
	if (_flagStolen isEqualTo const!(FLAG_STOLEN)) then
	{
		throw [["player", localize!("StolenFlag", _playerMention, _encodedTerritoryID)]];
	};

	private _currentLevel = _territory getVariable ["ExileTerritoryLevel", 0];
	private _upgradeListings = getArray(missionConfigFile >> "CfgTerritories" >> "Prices");
	private _maxLevel = count _upgradeListings;
	private _nextLevel = _currentLevel + 1;

	// The upgraded level must not be higher than the max level
	if (_nextLevel > _maxLevel) then
	{
		throw [["player", localize!("Upgrade_MaxLevel", _playerMention, _encodedTerritoryID)]];
	};

	//////////////////////
	// Modification
	//////////////////////

	// Gather the upgrade information
	private _upgradeListing = _upgradeListings select _currentLevel;
	private _territoryPrice = _upgradeListing select 0;
	private _territoryRange = _upgradeListing select 1;
	private _territoryMaxObjectCount = _upgradeListing select 2;

	// Calculate a payment tax. ESM_Taxes_TerritoryUpgrade is a decimal between 0 and 1
	private _tax = round(_territoryPrice * ESM_Taxes_TerritoryUpgrade);
	private _territoryPriceSubTotal = _territoryPrice + _tax;

	// If the player is online make sure to adjust their in-game data
	// Otherwise, we'll get their poptabs from the database itself
	private _playerMoney = 0;
	private _updatedPlayerMoney = 0;
	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;

	if (null?(_playerObject)) then // Because Arma!
	{
		// Locker check
		_playerMoney = format["getLocker:%1", _playerUID] call ExileServer_system_database_query_selectSingleField;
		if (_playerMoney < _territoryPriceSubTotal) then
		{
			throw [[
				"player",
				format[
					localize!("TooPoor_WithCost"),
					_playerMention,
					_territoryPriceSubTotal call ESMs_util_number_toString,
					_playerMoney call ESMs_util_number_toString
				]
			]];
		};

		_updatedPlayerMoney = _playerMoney - _territoryPriceSubTotal;
	}
	else
	{
		// Locker check
		_playerMoney = _playerObject getVariable ["ExileLocker", 0];
		if (_playerMoney < _territoryPriceSubTotal) then
		{
			throw [[
				"player",
				format[
					localize!("TooPoor_WithCost"),
					_playerMention,
					_territoryPriceSubTotal call ESMs_util_number_toString,
					_playerMoney call ESMs_util_number_toString
				]
			]];
		};

		// Adjust the players attributes and globally update
		_updatedPlayerMoney = _playerMoney - _territoryPriceSubTotal;
		_playerObject setVariable ["ExileLocker", _updatedPlayerMoney, true];
	};

	format[
		"updateLocker:%1:%2",
		_updatedPlayerMoney,
		_playerUID
	] call ExileServer_system_database_query_fireAndForget;

	format[
		"setTerritoryLevel:%1:%2",
		_nextLevel,
		_territoryDatabaseID
	] call ExileServer_system_database_query_fireAndForget;

	format[
		"setTerritorySize:%1:%2",
		_territoryRange,
		_territoryDatabaseID
	] call ExileServer_system_database_query_fireAndForget;

	_territory setVariable ["ExileTerritoryLevel", _nextLevel, true];
	_territory setVariable ["ExileTerritorySize", _territoryRange, true];

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
					localize!("Upgrade_Toast_Title"),
					localize!("Upgrade_Toast_Description", _nextLevel, _territoryRange)
				]
			]
		]
		call ExileServer_system_network_send_to;
	};

	// Tell ESM
	[
		// Response
		[
			_id,
			[
				[
					"author",
					localize!("ResponseAuthor", ESM_ServerID)
				],
				[
					"title",
					localize!("Upgrade_Response_Title", _encodedTerritoryID, _nextLevel)
				],
				[
					"fields",
					[
						[
							localize!("Upgrade_Response_Range_Title"),
							localize!("Upgrade_Response_Range_Value", _territoryRange),
							true
						],
						[
							localize!("Upgrade_Response_Objects_Title"),
							format[
								localize!("Upgrade_Response_Objects_Value"),
								_territory getVariable ["ExileTerritoryNumberOfConstructions", 0],
								_territoryMaxObjectCount
							],
							true
						],
						[
							localize!("Receipt"),
							format [
								localize!("Upgrade_Response_Receipt"),
								_playerMoney call ESMs_util_number_toString,
								_territoryPrice call ESMs_util_number_toString,
								_tax call ESMs_util_number_toString,
								ESM_Taxes_TerritoryUpgrade * 100,
								"%", // Because Arma
								_updatedPlayerMoney call ESMs_util_number_toString
							]
						]
					]
				]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["color", "green"],
				["title", localize!("Upgrade_Log_Title")],
				[
					"description",
					format [
						localize!("Upgrade_Log_Description"),
						_nextLevel,
						_playerMoney call ESMs_util_number_toString,
						_territoryPrice call ESMs_util_number_toString,
						_tax call ESMs_util_number_toString,
						ESM_Taxes_TerritoryUpgrade * 100,
						"%", // Because Arma
						_updatedPlayerMoney call ESMs_util_number_toString
					]
				],
				[
					"fields",
					[
						[
							localize!("Territory"),
							[
								["id", _encodedTerritoryID],
								["name", _territory getVariable ["ExileTerritoryName", "N/A"]]
							]
						],
						[localize!("Player"), _playerMetadata]
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
