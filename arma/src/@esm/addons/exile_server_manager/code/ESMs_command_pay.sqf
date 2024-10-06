/* ----------------------------------------------------------------------------
Function:
	ESMs_command_pay

Description:
	Handles paying a player's territory protection payment.
	A configurable tax will be added to the cost of the payment

Parameters:
	_this - [HashMap]

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
private _loggingEnabled = ESM_Logging_PayTerritory;

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

	// Player must be at least a builder
	if !([_territory, _playerUID] call ESMs_system_territory_checkAccess) then
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

	//////////////////////
	// Modification
	//////////////////////
	private _territoryPrice = (
		(_territory getVariable ["ExileTerritoryLevel", 1])
		*
		(getNumber (missionConfigFile >> "CfgTerritories" >> "popTabAmountPerObject"))
		*
		(_territory getVariable ["ExileTerritoryNumberOfConstructions", 0])
	);

	// Calculate a payment tax. ESM_Taxes_TerritoryPayment is a decimal between 0 and 1
	private _tax = round(_territoryPrice * ESM_Taxes_TerritoryPayment);
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
	]
	call ExileServer_system_database_query_fireAndForget;

	// Extend the due date of the territory
	_territory setVariable [
		"ExileTerritoryLastPayed",
		[] call ExileServer_util_time_currentTime
	];

	_territory call ExileServer_system_territory_maintenance_recalculateDueDate;

	// Save the due date in the database
	format[
		"maintainTerritory:%1",
		_territoryDatabaseID
	]
	call ExileServer_system_database_query_fireAndForget;

	// Send a broadcast on the XM8
	_territory call ExileServer_system_xm8_sendProtectionMoneyPaid;

	// Increase the payment counter
	_territory call ESMs_system_territory_incrementPaymentCounter;

	//////////////////////
	// Completion
	//////////////////////

	// Tell ESM
	[
		// Response
		[
			_id,
			[
				["author", localize!("ResponseAuthor", ESM_ServerID)],
				["title", localize!("Pay_Response_Title", _encodedTerritoryID)],
				[
					"description",
					format [
						localize!("Pay_Response_Receipt"),
						_playerMoney call ESMs_util_number_toString,
						_territoryPrice call ESMs_util_number_toString,
						_tax call ESMs_util_number_toString,
						ESM_Taxes_TerritoryPayment * 100,
						"%", // Because Arma
						_updatedPlayerMoney call ESMs_util_number_toString
					]
				]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Pay_Log_Title")],
				[
					"description",
					format [
						localize!("Pay_Log_Description"),
						_playerMoney call ESMs_util_number_toString,
						_territoryPrice call ESMs_util_number_toString,
						_tax call ESMs_util_number_toString,
						ESM_Taxes_TerritoryPayment * 100,
						"%", // Because Arma
						_updatedPlayerMoney call ESMs_util_number_toString
					]
				],
				["color", "green"],
				["fields", [
					[localize!("Territory"), [
						["id", _encodedTerritoryID],
						["name", _territory getVariable ["ExileTerritoryName", "N/A"]],
						["payment counter", _territory getVariable ["ESM_PaymentCounter", 0]]
					]],
					[localize!("Player"), _playerMetadata, true]
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
