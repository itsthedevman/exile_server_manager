/* ----------------------------------------------------------------------------
Function:
	ESMs_command_reward

Description:
	Rewards the player with money, respect, items and/or vehicles.

	Delivery is not all-or-nothing. Poptabs and respect always land once the player passes the guards, but individual
	items and vehicles can fail on their own, so the response reports exactly what did not make it and why. The bot
	writes those leftovers back onto the claim for another attempt rather than losing them.

Parameters:
	_this - [HashMap]

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _id = get!(_this, "id");

/*
  money: Scalar,
  locker: Scalar,
  respect: Scalar,
  items: HashMap<String, Scalar>,
  vehicles: Array<HashMap>
    class_name: String,
    spawn_location: String,
    territory_id: Scalar (optional),
    pin_code: String (optional)
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
private _loggingEnabled = ESM_Logging_CommandReward;

private _playerMetadata = get!(_metadata, "player");

private _playerUID = get!(_playerMetadata, "steam_uid");
private _playerMention = get!(_playerMetadata, "discord_mention");

try
{
	// Player must have joined the server at least once
	if !(_playerUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("PlayerNeedsToJoin", _playerMention, ESM_ServerID)]
		];
	};

	// Player must be alive in order to receive rewards
	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;
	if (isNull _playerObject || { !(alive _playerObject) }) then
	{
		throw [
			["player", localize!("AlivePlayer", _playerMention, ESM_ServerID)]
		];
	};

	//////////////////////
	// Modification
	//////////////////////

	private _receipt = [];
	private _undeliveredItems = createHashMap;
	private _undeliveredVehicles = [];
	private _failures = [];
	
	private _rewardMoney = get!(_data, "money", 0);
	private _rewardLocker = get!(_data, "locker", 0);
	private _rewardRespect = get!(_data, "respect", 0);
	private _rewardItems = get!(_data, "items", createHashMap);
	private _rewardVehicles = get!(_data, "vehicles", []);

	// Player money
	if (_rewardMoney > 0) then
	{
		private _playerMoney = _playerObject getVariable ["ExileMoney", 0];

		_playerMoney = _playerMoney + _rewardMoney;
		_playerObject setVariable ["ExileMoney", _playerMoney, true];

		format[
			"setPlayerMoney:%1:%2",
			_playerMoney,
			_playerObject getVariable ["ExileDatabaseID", -1]
		] call ExileServer_system_database_query_fireAndForget;

		_receipt pushBack [localize!("Reward_PlayerPoptabs"), _rewardMoney];
	};

	// Player locker
	if (_rewardLocker > 0) then
	{
		private _playerLocker = _playerObject getVariable ["ExileLocker", 0];

		_playerLocker = _playerLocker + _rewardLocker;
		_playerObject setVariable ["ExileLocker", _playerLocker, true];

		format[
			"updateLocker:%1:%2",
			_playerLocker,
			_playerUID
		] call ExileServer_system_database_query_fireAndForget;

		_receipt pushBack [localize!("Reward_LockerPoptabs"), _rewardLocker];
	};

	// Player Respect
	if (_rewardRespect > 0) then
	{
		private _playerRespect = _playerObject getVariable ["ExileScore", 0];

		_playerRespect = _playerRespect + _rewardRespect;
		_playerObject setVariable ["ExileScore", _playerRespect];

		format[
			"setAccountScore:%1:%2",
			_playerRespect,
			_playerUID
		] call ExileServer_system_database_query_fireAndForget;

		[_playerObject, _playerRespect] call ESMs_object_player_updateRespect;

		_receipt pushBack [localize!("Reward_Respect"), _rewardRespect];
	};

	// Items
	if !(empty?(_rewardItems)) then
	{
		{
			private _classname = _x;
			private _quantity = _y;

			// Ensure the item can be spawned
			private _configName = _classname call ExileClient_util_gear_getConfigNameByClassName;
			if !(isClass(configFile >> _configName >> _classname)) then
			{
				[
					["title", localize!("Reward_InvalidClassName_Title")],
					["description", localize!("Reward_InvalidClassName_Description", _classname)],
					["color", "yellow"]
				] call ESMs_system_network_discord_log;

				// A misconfigured classname cannot be retried into existence, so it is dropped rather than held.
				_failures pushBack [_classname, localize!("Reward_Failure_InvalidClassName")];

				continue;
			};

			private _quantityAdded = 0;
			for "_i" from 1 to _quantity do
			{
				private _added = false;

				// Attempt to add it to the players inventory
				if ([_playerObject, _classname] call ExileClient_util_playerCargo_canAdd) then
				{
					_added = [_playerObject, _classname] call ExileClient_util_playerCargo_add;
				};

				// It wasn't added, attempt to drop it on the ground
				if !(_added) then
				{
					private _lootHolder = objNull;
					private _nearestHolder = nearestObjects [
						_playerObject,
						["GroundWeaponHolder", "WeaponHolderSimulated", "LootWeaponHolder"],
						3 // Meters
					];

					// A holder was found
					if !(_nearestHolder isEqualTo []) then
					{
						_lootHolder = _nearestHolder select 0;
					};

					// No holder? Create one
					if (isNull _lootHolder) then
					{
						private _playerPosition = getPosATL _playerObject;

						_lootHolder = createVehicle [
							"GroundWeaponHolder",
							_playerPosition,
							[],
							3,
							"CAN_COLLIDE"
						];

						_lootHolder setPosATL _playerPosition;
						_lootHolder setVariable ["BIS_enableRandomization", false];
					};

					private _vehicleClass = getText(
						configfile >> _configName >> _classname >> "vehicleClass"
					);

					// Since backpacks are special...
					if (_vehicleClass isEqualTo "Backpacks") then
					{
						_lootHolder addBackpackCargoGlobal [_classname, 1];
					}
					else
					{
						_lootHolder addItemCargoGlobal [_classname, 1];
					};

					_added = true;
				};

				if (_added) then
				{
					_quantityAdded = _quantityAdded + 1;
				};
			};

			private _displayName = getText(configFile >> _configName >> _classname >> "displayName");

			if (_quantityAdded > 0) then
			{
				// We successfully added it, get the displayName so we can tell the player
				_receipt pushBack [_displayName, _quantityAdded];
			};

			// Hold back whatever would not fit so the player can claim the rest later
			if (_quantityAdded < _quantity) then
			{
				private _remaining = _quantity - _quantityAdded;

				_undeliveredItems set [_classname, _remaining];
				_failures pushBack [_displayName, localize!("Reward_Failure_NoRoom", _remaining)];
			};
		}
		forEach _rewardItems;
	};

	// Vehicles
	if !(empty?(_rewardVehicles)) then
	{
		{
			private _vehicle = _x;

			// The vehicle system arrived in 2.1.0. Anything sending vehicles knows that, so a malformed entry is a bug
			// worth skipping rather than aborting the whole package over.
			if !(type?(_vehicle, HASH)) then { continue; };

			([_playerObject, _vehicle] call ESMs_object_vehicle_spawnReward) params [
				"_delivered",
				"_reason",
				"_displayName",
				"_pinCode"
			];

			if (_delivered) then
			{
				_receipt pushBack [
					format["%1 (%2)", _displayName, localize!("Reward_Vehicle_PinCode", _pinCode)],
					1
				];

				continue;
			};

			_undeliveredVehicles pushBack _vehicle;

			private _reasonText = switch (_reason) do
			{
				case "invalid_class": { localize!("Reward_Failure_InvalidClassName") };
				case "unsupported_location": { localize!("Reward_Failure_UnsupportedLocation") };
				case "no_safe_position": { localize!("Reward_Failure_NoSafePosition") };
				case "territory_not_found": { localize!("Reward_Failure_TerritoryNotFound") };
				case "no_garage": { localize!("Reward_Failure_NoGarage") };
				case "garage_full": { localize!("Reward_Failure_GarageFull") };
				default { localize!("Reward_Failure_Unknown") };
			};

			_failures pushBack [_displayName, _reasonText];
		}
		forEach _rewardVehicles;
	};

	//////////////////////
	// Completion
	//////////////////////
	private _receiptText = [
		_receipt,
		// Creates "50x Player Poptabs", "15x Respect", "1x Trollinator", etc.
		{ format["- %1x %2", _this select 1, _this select 0] }
	] call ESMs_util_array_map;

	_receiptText = _receiptText joinString "<br/>";

	private _failureText = [
		_failures,
		{ format["- %1: %2", _this select 0, _this select 1] }
	] call ESMs_util_array_map;

	_failureText = _failureText joinString "<br/>";

	private _partial = !empty?(_failures);

	private _description = if (_partial) then
	{
		localize!("Reward_Response_Partial_Description", _playerMention, _receiptText, _failureText)
	}
	else
	{
		localize!("Reward_Response_Description", _playerMention, _receiptText)
	};

	private _title = if (_partial) then
	{
		localize!("Reward_Response_Partial_Title")
	}
	else
	{
		localize!("Reward_Response_Title")
	};

	[
		// Response
		[
			_id,
			[
				["state", if (_partial) then { "partial" } else { "success" }],
				[
					"embed",
					[
						["author", localize!("ResponseAuthor", ESM_ServerID)],
						["title", _title],
						["description", _description],
						["color", if (_partial) then { "yellow" } else { "green" }]
					]
				],
				["undelivered_items", _undeliveredItems],
				["undelivered_vehicles", _undeliveredVehicles],
				["failures", _failures]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Reward_Log_Title")],
				["description", localize!("Reward_Log_Description", _receiptText)],
				["color", if (_partial) then { "yellow" } else { "green" }],
				["fields", [
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
