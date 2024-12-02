/* ----------------------------------------------------------------------------
Function:
	ESMs_command_reward

Description:
	Rewards the player with money, respect, and/or items

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
  poptabs: Scalar,
  locker: Scalar,
  respect: Scalar,
  items: HashMap<String, Scalar>
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
	private _rewardMoney = get!(_data, "money", 0);
	private _rewardLocker = get!(_data, "locker", 0);
	private _rewardRespect = get!(_data, "respect", 0);
	private _rewardItems = get!(_data, "items", []);

	// Player money
	if (_rewardMoney > 0) then
	{
		private _playerMoney = _playerObject getVariable ["ExileMoney", 0];

		_playerMoney = _playerMoney + _rewardMoney;
		_playerObject setVariable ["ExileMoney", _playerMoney, true];

		format[
			"setPlayerMoney:%1:%2",
			_playerMoney,
			_playerObject getVariable ["ExileDatabaseID", 0]
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
	if !(_rewardItems isEqualTo []) then
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

			if (_quantityAdded > 0) then
			{
				// We successfully added it, get the displayName so we can tell the player
				_receipt pushBack [
					getText(configFile >> _configName >> _classname >> "displayName"),
					_quantityAdded
				];
			};
		}
		forEach _rewardItems;
	};

	//////////////////////
	// Completion
	//////////////////////
	_receipt = [
		_receipt,
		// Creates "50x Player Poptabs", "15x Respect", "1x Trollinator", etc.
		{ format["- %1x %2", _this select 1, _this select 0] }
	] call ESMs_util_array_map;

	_receipt = _receipt joinString "<br/>";

	[
		// Response
		[
			_id,
			[
				["author", localize!("ResponseAuthor", ESM_ServerID)],
				["title", localize!("Reward_Response_Title")],
				[
					"description",
					localize!("Reward_Response_Description", _playerMention, _receipt)
				]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Reward_Log_Title")],
				["description", localize!("Reward_Log_Description", _receipt)],
				["color", "green"],
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
