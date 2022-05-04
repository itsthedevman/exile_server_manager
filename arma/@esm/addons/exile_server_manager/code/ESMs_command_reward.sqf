/* ----------------------------------------------------------------------------
Function: ESMs_command_reward

Description:
	Grants a player a reward
	Called from ESMs_system_extension_callback as part of a command workflow.
	Do not call manually unless you know what you're doing!

Parameters:
	_this  -  A hashmap representation of a ESM message [Hashmap]

Returns:
	Nothing

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */


private _id = _this getOrDefault ["id", nil];

/*
	player_poptabs: Scalar,
    locker_poptabs: Scalar,
    respect: Scalar,
    items: String,
    vehicles: String,
*/
private _data = _this getOrDefault ["data", nil];

/*
	player: HashMap
		steam_uid: String,
		discord_id: String,
		discord_name: String,
		discord_mention: String,
	target: Nothing
*/
private _metadata = _this getOrDefault ["metadata", nil];
if (isNil "_id" || { isNil "_data" } || { isNil "_metadata" }) exitWith { nil };

try
{
	// Here we go! Start off by checking to make sure the player is online and alive
	private _playerUID = [_metadata, "player", "steam_uid"] call ESMs_util_hashmap_get;
	private _playerMention = [_metadata, "player", "discord_mention"] call ESMs_util_hashmap_get;
	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;

	if (isNull _playerObject) exitWith
	{
		throw format[localize "$STR_ESM_NullPlayer", _playerMention, ESM_ServerID];
	};

	if !(alive _playerObject) then
	{
		throw format[localize "$STR_ESM_AlivePlayer", _playerMention, ESM_ServerID];
	};

	private _receipt = createHashMap;

	// Process Poptabs (player)
	private _rewardPlayerPoptabs = parseNumber(_data getOrDefault ["player_poptabs", "0"]);
	if (_rewardPlayerPoptabs > 0) then
	{
		private _playerMoney = _playerObject getVariable ["ExileMoney", 0];

		_playerMoney = _playerMoney + _rewardPlayerPoptabs;
		_playerObject setVariable ["ExileMoney", _playerMoney, true];

		format["setPlayerMoney:%1:%2", _playerMoney, _playerObject getVariable ["ExileDatabaseID", 0]] call ExileServer_system_database_query_fireAndForget;

		_receipt set ["player_poptabs", _playerMoney];
	};

	// Process Poptabs (Locker)
	private _rewardLockerPoptabs = parseNumber(_data getOrDefault ["locker_poptabs", "0"]);
	if (_rewardLockerPoptabs > 0) then
	{
		private _playerLocker = _playerObject getVariable ["ExileLocker", 0];

		_playerLocker = _playerLocker + _rewardLockerPoptabs;
		_playerObject setVariable ["ExileLocker", _playerLocker, true];

		format["updateLocker:%1:%2", _playerLocker, _playerUID] call ExileServer_system_database_query_fireAndForget;

		_receipt set ["locker_poptabs", _playerLocker];
	};

	// Process Respect
	private _rewardRespect = parseNumber(_data getOrDefault ["respect", "0"]);
	if (_rewardRespect > 0) then
	{
		private _playerRespect = _playerObject getVariable ["ExileScore", 0];

		_playerRespect = _playerRespect + _rewardRespect;
		_playerObject setVariable ["ExileScore", _playerRespect];

		// Update the client's cache
		[_playerRespect, { ExileClientPlayerScore = _this; }] remoteExecCall ["call", owner _playerObject];

		format["setAccountScore:%1:%2", _playerRespect, _playerUID] call ExileServer_system_database_query_fireAndForget;

		_receipt set ["respect", _playerRespect];
	};

	// Process Items
	private _rewardItems = _data getOrDefault ["items", []];
	if !(_rewardItems isEqualTo []) then
	{
		{
			private _classname = _x;
			private _quantity = parseNumber(_y);
			private _added = false;
			private _configName = _classname call ExileClient_util_gear_getConfigNameByClassName;

			if (isClass(configFile >> _configName >> _classname)) then
			{
				for "_i" from 1 to _quantity do
				{
					// Attempt to add it to the players inventory
					if ([_playerObject, _classname] call ExileClient_util_playerCargo_canAdd) then
					{
						_added = [_playerObject, _classname] call ExileClient_util_playerCargo_add;
					};

					// It wasn't added, attempt to drop it on the ground
					if !(_added) then
					{
						private _playerPosition = getPosATL _playerObject;
						private _lootHolder = objNull;
                        private _nearestHolder = nearestObjects [_playerObject, ["GroundWeaponHolder", "WeaponHolderSimulated", "LootWeaponHolder"], 3];

						// Get the nearest loot holder
                        if !(_nearestHolder isEqualTo []) then
                        {
                            _lootHolder = _nearestHolder select 0;
                        };

						// If there are none, spawn one nearby
                        if (isNull _lootHolder) then
                        {
                            _lootHolder = createVehicle ["GroundWeaponHolder", _playerPosition, [], 3, "CAN_COLLIDE"];
                            _lootHolder setPosATL _playerPosition;
                            _lootHolder setVariable ["BIS_enableRandomization", false];
                        };

						// If it is a backpack, add it using a different command. Because.
						if (getText(configfile >> _configName >> _classname >> "vehicleClass") isEqualTo "Backpacks") then
                        {
                            _lootHolder addBackpackCargoGlobal [_classname, 1];
                        }
                        else
                        {
							// And everything else is an item
                            _lootHolder addItemCargoGlobal [_classname, 1];
                        };

						_added = true;
					};

					if (_added) then
					{
						private _items = _receipt getOrDefault ["items", createHashMap];
						private _currentQuantity = _items getOrDefault [_classname, 0];

						// Increase the quantity
						_items set [_classname, _currentQuantity + 1];

						// Set the items back
						_receipt set ["items", _items];
					};
				};
			}
			else
			{
				["reward", format[localize "$STR_ESM_Reward_InvalidItem", _classname], "warn"] call ESMs_util_log;
			};
		}
		forEach _rewardItems;
	};

	// Process Vehicles
	private _rewardVehicles = _data getOrDefault ["vehicles", []];
	if !(_rewardVehicles isEqualTo []) then
	{
		{
			private _success = false;
			private _vehicleClass = _x get "class_name";
			private _location = _x get "location";
			private _pinCode = _x get "code";
			private _isShip = _vehicleClass isKindOf "Ship";
			private _position = [];

			// Skip finding a position if the vehicle is to be added to the garage
			if !(_addToGarage) then
			{
				if (_isShip) then
				{
					_position = [(getPosATL _playerObject), 80, 10] call ExileClient_util_world_findWaterPosition;
				}
				else
				{
					_position = (getPos _playerObject) findEmptyPosition [10, 175, _vehicleClass];
				};
			};


			// Add to player's garage
			if (_position isEqualTo []) then
			{
				// TODO, add the vehicle to the garage
			}
			else
			{
				// Spawn it at the position
				_vehicleObject = [_vehicleClass, _position, (random 360), !_isShip, _pinCode] call ExileServer_object_vehicle_createPersistentVehicle;

				// Set ownership
				_vehicleObject setVariable ["ExileOwnerUID", _playerUID];
				_vehicleObject setVariable ["ExileIsLocked", 0];
				_vehicleObject lock 0;

				// Save vehicle in database + update position/stats
				_vehicleObject call ExileServer_object_vehicle_database_insert;
				_vehicleObject call ExileServer_object_vehicle_database_update;

				_success = true
			};

			if (_success) then
			{
				private _items = _receipt getOrDefault ["vehicles", createHashMap];
				private _currentQuantity = _items getOrDefault [_vehicleClass, 0];

				// Increase the quantity
				_items set [_vehicleClass, _currentQuantity + 1];

				// Set the items back
				_receipt set ["vehicles", _items];
			};
		}
		forEach _rewardVehicles;
	};

	[_id, "arma", "reward", _receipt] spawn ESMs_object_message_respond_to;

	if (ESM_Logging_RewardPlayer) then
	{
		private _embed = [["description", format[localize "$STR_ESM_Reward_LogDescription", _playerMention]]] call ESMs_object_embed_create;
		[_embed, localize "$STR_ESM_Reward_Log_Field1_Name", _playerUID] call ESMs_object_embed_addField;
		[_embed, localize "$STR_ESM_Reward_Log_Field2_Name", _receipt] call ESMs_object_embed_addField;

		_embed spawn ESMs_system_network_discord_log;
	};
}
catch
{
	[_id, _exception] spawn ESMs_object_message_respond_withError;
};

nil
