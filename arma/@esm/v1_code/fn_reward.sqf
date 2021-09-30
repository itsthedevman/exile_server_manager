/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Rewards the player with preconfigured poptabs, respect, and items
*/
params ["_commandID", "_authorInfo", "_playerUID"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

try
{
	// Don't allow adding people who aren't part of this server (also catches discord id mistakes. ;))
	if !(format["isKnownAccount:%1", _playerUID] call ExileServer_system_database_query_selectSingleField) then
	{
		throw ["", format["%1, you have not joined this server yet", _authorTag]];
	};

	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;


	if (isNull _playerObject) then
	{
		throw ["", format["%1, you need to logged into the server first", _authorTag]];
	};

	if !(alive _playerObject) then
	{
		throw ["", format["%1, your player is no longer alive. You will need to respawn before you can claim your reward", _authorTag]];
	};

	private _receipt = [];

	// Process Poptabs (player)
	if (ESM_RewardPoptabsPlayer > 0) then
	{
		private _playerMoney = _playerObject getVariable ["ExileMoney", 0];
		_playerMoney = _playerMoney + ESM_RewardPoptabsPlayer;
		_playerObject setVariable ["ExileMoney", _playerMoney, true];
		format["setPlayerMoney:%1:%2", _playerMoney, _playerObject getVariable ["ExileDatabaseID", 0]] call ExileServer_system_database_query_fireAndForget;
		_receipt pushBack ["Poptabs (Player)", ESM_RewardPoptabsPlayer];
	};

	// Process Poptabs (Locker)
	if (ESM_RewardPoptabsLocker > 0) then
	{
		private _playerLocker = _playerObject getVariable ["ExileLocker", 0];
		_playerLocker = _playerLocker + ESM_RewardPoptabsLocker;
		_playerObject setVariable ["ExileLocker", _playerLocker, true];
		format["updateLocker:%1:%2", _playerLocker, _playerUID] call ExileServer_system_database_query_fireAndForget;
		_receipt pushBack ["Poptabs (Locker)", ESM_RewardPoptabsLocker];
	};

	// Process Respect
	if (ESM_RewardRespect > 0) then
	{
		private _playerRespect = _playerObject getVariable ["ExileScore", 0];
		_playerRespect = _playerRespect + ESM_RewardRespect;
		_playerObject setVariable ["ExileScore", _playerRespect];
		[_playerRespect, { ExileClientPlayerScore = _this; }] remoteExecCall ["call", owner _playerObject];
		format["setAccountScore:%1:%2", _playerRespect, (getPlayerUID _playerObject)] call ExileServer_system_database_query_fireAndForget;
		_receipt pushBack ["Respect", ESM_RewardRespect];
	};

	// Process Items
	if !(ESM_RewardItems isEqualTo []) then
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

                        if !(_nearestHolder isEqualTo []) then
                        {
                            _lootHolder = _nearestHolder select 0;
                        };

                        if (isNull _lootHolder) then
                        {
                            _lootHolder = createVehicle ["GroundWeaponHolder", _playerPosition, [], 3, "CAN_COLLIDE"];
                            _lootHolder setPosATL _playerPosition;
                            _lootHolder setVariable ["BIS_enableRandomization", false];
                        };

						if (getText(configfile >> _configName >> _classname >> "vehicleClass") isEqualTo "Backpacks") then
                        {
                            _lootHolder addBackpackCargoGlobal [_classname, 1];
                        }
                        else
                        {
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
		forEach ESM_RewardItems;
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
