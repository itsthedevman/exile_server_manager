/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Modifies the player on the server
*/
params ["_commandID", "_authorInfo", "_discordTag", "_targetUID", "_type", "_value"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];

private _isOnline = false;
private _previousValue = 0;
private _info = [];
private _logMessage = [];

try
{
	// Don't allow adding people who aren't part of this server (also catches discord id mistakes. ;))
	if !(format["isKnownAccount:%1", _targetUID] call ExileServer_system_database_query_selectSingleField) then
	{
		throw ["", format["%1, `%2` does not exist on this server", _authorTag, _targetUID]];
	};

	_value = parseNumber(_value);

	private _playerObject = _targetUID call ExileClient_util_player_objectFromPlayerUID;
	_isOnline = !(isNull _playerObject);

	switch (toLower(_type)) do
	{
		case "money":
		{
			private _dbID = -1;
			_previousValue = 0;
			if (_isOnline) then
			{
				_previousValue = _playerObject getVariable ["ExileMoney", 0];
				_playerObject setVariable ["ExileMoney", _previousValue + _value, true];
				_dbID = _playerObject setVariable ["ExileDatabaseID", -1];
			}
			else
			{
				_playerData = format["loadPlayer:%1", _targetUID] call ExileServer_system_database_query_selectSingle;
				_dbID = _playerData select 0;
				_previousValue = format["getPlayerMoney:%1", _dbID] call ExileServer_system_database_query_selectSingleField;
			};

			format["setPlayerMoney:%1:%2", _previousValue + _value, _dbID] call ExileServer_system_database_query_fireAndForget;

			_info = [
				["type", toLower(_type)],
				["modified_amount", _value],
				["previous_amount", _previousValue],
				["new_amount", (_previousValue + _value)]
			];

			_logMessage = [
				"",
				format["%1 modified a player's poptabs by **%2**", _authorTag, _value],
				[
					["Target UID", _targetUID, true],
					["Previous Amount", _previousValue, true],
					["New Amount", (_previousValue + _value), true]
				]
			];
		};

		case "respect":
		{
			_previousValue = format["getAccountScore:%1", _targetUID] call ExileServer_system_database_query_selectSingleField;
			format["setAccountScore:%1:%2", _previousValue + _value, _targetUID] call ExileServer_system_database_query_fireAndForget;
			if (_isOnline) then
			{
				_playerObject setVariable ["ExileScore", _previousValue + _value];
				[_previousValue + _value, { ExileClientPlayerScore = _this; }] remoteExecCall ["call", owner _playerObject];
			};
			_info = [
				["type", toLower(_type)],
				["modified_amount", _value],
				["previous_amount", _previousValue],
				["new_amount", (_previousValue + _value)]
			];

			_logMessage = [
				"",
				format["%1 modified a player's respect by **%2**", _authorTag, _value],
				[
					["Target UID", _targetUID, true],
					["Previous Amount", _previousValue, true],
					["New Amount", (_previousValue + _value), true]
				]
			];
		};

		case "locker":
		{
			_previousValue = format["getLocker:%1", _targetUID] call ExileServer_system_database_query_selectSingleField;
			format["updateLocker:%1:%2", _previousValue + _value, _targetUID] call ExileServer_system_database_query_fireAndForget;
			if (_isOnline) then
			{
				_playerObject setVariable ["ExileLocker", _previousValue + _value, true];
			};
			_info = [
				["type", toLower(_type)],
				["modified_amount", _value],
				["previous_amount", _previousValue],
				["new_amount", (_previousValue + _value)]
			];
			_logMessage = [
				"",
				format["%1 modified a player's locker poptabs by **%2**", _authorTag, _value],
				[
					["Target UID", _targetUID, true],
					["Previous Amount", _previousValue, true],
					["New Amount", (_previousValue + _value), true]
				]
			];
		};

		case "heal":
		{
			if (_isOnline) then
			{
				_playerObject setDamage 0;
				{
					ExileClientPlayerAttributes = [100,100,100,100,0,37,0];
					ExileClientPlayerAttributesASecondAgo = ExileClientPlayerAttributes;
					ExileClientPlayerLastHpRegenerationAt = diag_tickTime;
					ExileClientPlayerIsOverburdened = false;
					ExileClientPlayerOxygen = 100;
					ExileClientPlayerIsAbleToBreathe = true;
					ExileClientPlayerIsDrowning = false;
					ExileClientPlayerIsInjured = false;
					ExileClientPlayerIsBurning = false;
					ExileClientPlayerIsBleeding = false;
					ExileClientPlayerIsExhausted = false;
					ExileClientPlayerIsHungry = false;
					ExileClientPlayerIsThirsty = false;
					player setBleedingRemaining 0;
					player setOxygenRemaining 1;
					player setFatigue 0;
				} remoteExecCall ["call", owner _playerObject];
			}
			else
			{
				_playerData = format["loadPlayer:%1", _targetUID] call ExileServer_system_database_query_selectSingle;
				_extDB2Message = ["updatePlayer", [
					_playerData select 1, // name
					0, // damage
					100, // hunger
					100, // thirst
					0, // alcohol
					1, // oxygen_remaining
					0, // bleeding_remaining
					_playerData select 9, // hitpoints
					_playerData select 10, // direction
					_playerData select 11, // position_x
					_playerData select 12, // position_y
					_playerData select 13, // position_z
					_playerData select 14, // assigned_items
					_playerData select 15, // backpack
					_playerData select 16, // backpack_items
					_playerData select 17, // backpack_magazines
					_playerData select 18, // backpack_weapons
					_playerData select 19, // current_weapon
					_playerData select 20, // goggles
					_playerData select 21, // handgun_items
					_playerData select 22, // handgun_weapon
					_playerData select 23, // headgear
					_playerData select 24, // binocular
					_playerData select 25, // loaded_magazines
					_playerData select 26, // primary_weapon
					_playerData select 27, // primary_weapon_items
					_playerData select 28, // secondary_weapon
					_playerData select 29, // secondary_weapon_items
					_playerData select 30, // uniform
					_playerData select 31, // uniform_items
					_playerData select 32, // uniform_magazines
					_playerData select 33, // uniform_weapons
					_playerData select 34, // vest
					_playerData select 35, // vest_items
					_playerData select 36, // vest_magazines
					_playerData select 37, // vest_weapons
					37, // temperature
					0, // wetness
					_playerData select 0 // id
				]] call ExileServer_util_extDB2_createMessage;
				_extDB2Message call ExileServer_system_database_query_fireAndForget;
			};

			_info = [
				["type", toLower(_type)]
			];
			_logMessage = [
				"",
				format["%1 healed a player", _authorTag],
				[
					["Target UID", _targetUID, true]
				]
			];
		};

		case "kill":
		{
			_info = [
				["type", toLower(_type)]
			];

			if (_isOnline) then
			{
				_info pushBack (["name", name _playerObject]);
				_playerObject setDamage 666;
			}
			else
			{
				_playerData = format["loadPlayer:%1", _targetUID] call ExileServer_system_database_query_selectSingle;

				if (isNil "_playerData") then
				{
					throw ["", format["`%1` is already dead", _targetUID]];
				};

				_info pushBack (["name", format["%1", _playerData select 1]]);

				if ((getNumber (configFile >> "CfgSettings" >> "Logging" >> "deathLogging")) isEqualTo 1) then
				{
					ESM_DatabaseVersion callExtension format["1:DEATH:%1", format["%1 was killed by %2 via ESM", _playerData select 1, _discordTag]];
				};

				// Create new record in the history
				format["insertPlayerHistory:%1:%2:%3:%4:%5", _targetUID, _playerData select 1, _playerData select 11, _playerData select 12, _playerData select 13] call ExileServer_system_database_query_fireAndForget;

				// Delete the player record
				format["deletePlayer:%1", _playerData select 0] call ExileServer_system_database_query_fireAndForget;
			};

			_logMessage = [
				"",
				format["%1 killed a player", _authorTag],
				[
					["Target UID", _targetUID, true]
				]
			];
		};

		default
		{
			throw ["", format["`%1` is not a valid type", _type]];
		};
	};

	// Let the player know in discord
	[_commandID, _info] call ESM_fnc_respond;

	if (ESM_Logging_ModifyPlayer) then
	{
		// Let our logging channel know..
		["success", "embed", _logMessage] call ESM_fnc_logToDiscord;
	};
}
catch
{
	if !((_exception select 0) isEqualTo "") then
	{
		["fn_modifyPlayer", _exception select 0] call ESM_fnc_log;

		if (ESM_Logging_ModifyPlayer) then
		{
			["error", "message", [_exception select 0]] call ESM_fnc_logToDiscord;
		};
	};

	if !((_exception select 1) isEqualTo "") then
	{
		[_commandID, [["error", _exception select 1]]] call ESM_fnc_respond;
	};
};

true
