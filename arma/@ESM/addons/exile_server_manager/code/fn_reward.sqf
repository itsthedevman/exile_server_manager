params ["_commandID", "_parameters", "_metadata"];
_parameters params [
	"_playerUID",
	["_rewardItems", [], [[]]],
	["_rewardVehicles", [], [[]]],
	["_rewardPoptabsPlayer", 0, [0]],
	["_rewardPoptabsLocker", 0, [0]],
	["_rewardRespect", 0, [0]]
];
// _metadata params ["_userID", "_userName", "_userMention", "userSteamUID"];

try
{
	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;

	if (isNull _playerObject) exitWith
	{
		[_commandID, "null_player"] call ESM_fnc_respondWithErrorCode;
	};

	if !(alive _playerObject) then
	{
		throw ["", format["%1, your player is no longer alive. You will need to respawn before you can claim your reward", _authorTag]];
	};

	private _receipt = [];

	// Process Poptabs (player)
	if (_rewardPoptabsPlayer > 0) then
	{
		private _playerMoney = _playerObject getVariable ["ExileMoney", 0];

		_playerMoney = _playerMoney + _rewardPoptabsPlayer;
		_playerObject setVariable ["ExileMoney", _playerMoney, true];

		format["setPlayerMoney:%1:%2", _playerMoney, _playerObject getVariable ["ExileDatabaseID", 0]] call ExileServer_system_database_query_fireAndForget;

		_receipt pushBack ["Poptabs (Player)", _rewardPoptabsPlayer];
	};

	// Process Poptabs (Locker)
	if (_rewardPoptabsLocker > 0) then
	{
		private _playerLocker = _playerObject getVariable ["ExileLocker", 0];

		_playerLocker = _playerLocker + _rewardPoptabsLocker;
		_playerObject setVariable ["ExileLocker", _playerLocker, true];

		format["updateLocker:%1:%2", _playerLocker, _playerUID] call ExileServer_system_database_query_fireAndForget;

		_receipt pushBack ["Poptabs (Locker)", _rewardPoptabsLocker];
	};

	// Process Respect
	if (_rewardRespect > 0) then
	{
		private _playerRespect = _playerObject getVariable ["ExileScore", 0];

		_playerRespect = _playerRespect + _rewardRespect;
		_playerObject setVariable ["ExileScore", _playerRespect];

		// Update the client's cache
		[_playerRespect, { ExileClientPlayerScore = _this; }] remoteExecCall ["call", owner _playerObject];

		format["setAccountScore:%1:%2", _playerRespect, (getPlayerUID _playerObject)] call ExileServer_system_database_query_fireAndForget;

		_receipt pushBack ["Respect", _rewardRespect];
	};

	// Process Items
	if !(_rewardItems isEqualTo []) then
	{
		{
			private _classname = _x select 0;
			private _quantity = _x select 1;
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

						// Get the nearest lootholder
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

					// We successfully added it, get the displayName so we can tell the player
					if (_added) then
					{
						private _displayName = getText(configFile >> _configName >> _classname >> "displayName");
						_receipt pushBack [_displayName, _quantity];
					};
				};
			}
			else
			{
				["error", "message", [format["**WARNING:** You have `%1` listed as an item reward, however, this item's config does not exist on your server\nPlease double check your spelling, add the required mod, or remove this item from the rewards for this server", _classname]]] call ESM_fnc_logToDiscord;
			};
		}
		forEach _rewardItems;
	};

	// Process Vehicles
	if !(_rewardVehicles isEqualTo []) then
	{
		{
			private _vehicleClass = _x select 0;
			private _quantity = _x select 1;
			private _addToGarage = _x select 2;
			private _pinCode = _x select 3;
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
				_vehicleObject setVariable ["ExileIsLocked",0];
				_vehicleObject lock 0;

				// Save vehicle in database + update position/stats
				_vehicleObject call ExileServer_object_vehicle_database_insert;
				_vehicleObject call ExileServer_object_vehicle_database_update;
			};
		}
		forEach _rewardVehicles;

	};

	// Let the player know in discord
	[_commandID, [["receipt", _receipt]]] call ESM_fnc_respond;

	if (ESM_Logging_RewardPlayer) then
	{
		["success", "embed", ["", format["%1 received rewards", _authorTag], [["Member UID", _playerUID], ["Receipt", _receipt]]]] call ESM_fnc_logToDiscord;
	};
}
catch
{
	if !((_exception select 0) isEqualTo "") then
	{
		["fn_rewardPlayer", _exception select 0] call ESM_fnc_log;
		if (ESM_Logging_RewardPlayer) then
		{
			["error", "message", [_exception select 0]] call ESM_fnc_logToDiscord;
		};
	};

	if !((_exception select 1) isEqualTo "") then
	{
		[_commandID, [["error", _exception select 1]]] call ESM_fnc_respond;
	};
};
