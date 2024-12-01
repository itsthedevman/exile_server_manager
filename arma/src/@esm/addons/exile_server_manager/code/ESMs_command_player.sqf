/* ----------------------------------------------------------------------------
Function:
	ESMs_command_player

Description:
	Modifies the player on the server

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
  action: String
  amount: Integer
*/
private _data = get!(_this, "data");

/*
  player: HashMap
    steam_uid: String,
    discord_id: String,
    discord_name: String,
    discord_mention: String,
  target: HashMap
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
private _loggingEnabled = ESM_Logging_CommandPlayer;

private _playerMetadata = get!(_metadata, "player");
private _targetMetadata = get!(_metadata, "target");

private _playerUID = get!(_playerMetadata, "steam_uid");
private _targetUID = get!(_targetMetadata, "steam_uid");

private _playerMention = get!(_playerMetadata, "discord_mention");
private _targetMention = get!(_targetMetadata, "discord_mention");

private _action = get!(_data, "action");
private _amount = parseNumber(get!(_data, "amount"));

try
{
	//////////////////////
	// Validation
	//////////////////////

	// Player must have joined the server at least once
	if !(_playerUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("PlayerNeedsToJoin", _playerMention, ESM_ServerID)]
		];
	};

	// Target player must have joined the server at least once
	if !(_targetUID call ESMs_system_account_isKnown) then
	{
		throw [
			["player", localize!("TargetNeedsToJoin", _playerMention, _targetMention, ESM_ServerID)]
		];
	};

	// If the player is online make sure to adjust their in-game data
	private _playerObject = _targetUID call ExileClient_util_player_objectFromPlayerUID;

	private _isOnline = !(isNull _playerObject);
	private _response = [];
	private _logDescription = [];

	//////////////////////
	// Modification
	//////////////////////
	switch (toLower(_action)) do
	{
		// Modify the player's money
		case "money":
		{
			private _previousAmount = 0;
			private _databaseID = -1;

			if (_isOnline) then
			{
				_previousAmount = _playerObject getVariable ["ExileMoney", 0];
				_playerObject setVariable ["ExileMoney", _previousAmount + _amount, true];

				_databaseID = _playerObject setVariable ["ExileDatabaseID", -1];
			}
			else
			{
				_playerData = format[
					"loadPlayer:%1",
					_targetUID
				] call ExileServer_system_database_query_selectSingle;

				_databaseID = _playerData select 0;

				_previousAmount = format[
					"getPlayerMoney:%1",
					_databaseID
				] call ExileServer_system_database_query_selectSingleField;
			};

			private _newAmount = _previousAmount + _amount;

			format[
				"setPlayerMoney:%1:%2",
				_newAmount,
				_databaseID
			] call ExileServer_system_database_query_fireAndForget;

			_response = [
				["modified_amount", _amount],
				["previous_amount", _previousAmount],
				["new_amount", _newAmount]
			];

			_logDescription = localize!("Player_Log_Description_Money", _amount, _newAmount);
		};

		// Modify the player's respect/score
		case "respect":
		{
			private _previousAmount = format[
				"getAccountScore:%1",
				_targetUID
			] call ExileServer_system_database_query_selectSingleField;

			private _newAmount = _previousAmount + _amount;

			format[
				"setAccountScore:%1:%2",
				_newAmount,
				_targetUID
			] call ExileServer_system_database_query_fireAndForget;

			if (_isOnline) then
			{
				_playerObject setVariable ["ExileScore", _newAmount];

				[
					_newAmount,
					{ ExileClientPlayerScore = _this; }
				] remoteExecCall ["call", owner _playerObject];
			};

			_response = [
				["modified_amount", _amount],
				["previous_amount", _previousAmount],
				["new_amount", _newAmount]
			];

			_logDescription = localize!("Player_Log_Description_Respect", _amount, _newAmount);
		};

		// Modify the player's locker
		case "locker":
		{
			private _previousAmount = format[
				"getLocker:%1",
				_targetUID
			] call ExileServer_system_database_query_selectSingleField;

			private _newAmount = _previousAmount + _amount;

			format[
				"updateLocker:%1:%2",
				_newAmount,
				_targetUID
			] call ExileServer_system_database_query_fireAndForget;

			if (_isOnline) then
			{
				_playerObject setVariable ["ExileLocker", _newAmount, true];
			};

			_response = [
				["modified_amount", _amount],
				["previous_amount", _previousAmount],
				["new_amount", _newAmount]
			];

			_logDescription = localize!("Player_Log_Description_Locker", _amount, _newAmount);
		};

		// Heal the player
		case "heal":
		{
			if (_isOnline) then
			{
				_playerObject setDamage 0;

				{
					ExileClientPlayerAttributes = [
						100,  // health
						100,  // stamina
						100,  // hunger
						100,  // thirst
						0,    // alcohol
						37,   // temperature
						0     // wetness
					];

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
				_playerData = format[
					"loadPlayer:%1",
					_targetUID
				] call ExileServer_system_database_query_selectSingle;

				_query = ["updatePlayer", [
					_playerData select 1,  // name
					0, 					   // damage
					100, 				   // hunger
					100, 				   // thirst
					0, 					   // alcohol
					1, 					   // oxygen_remaining
					0, 					   // bleeding_remaining
					_playerData select 9,  // hitpoints
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
					37, 				   // temperature
					0, 					   // wetness
					_playerData select 0   // uid
				]] call ExileServer_util_extDB2_createMessage;

				_query call ExileServer_system_database_query_fireAndForget;
			};

			_logDescription = localize!("Player_Log_Description_Heal");
		};

		// Kill the player
		case "kill":
		{
			if (_isOnline) then
			{
				_playerObject setDamage 666;
			}
			else
			{
				_playerData = format[
					"loadPlayer:%1",
					_targetUID
				] call ExileServer_system_database_query_selectSingle;

				if (isNil "_playerData") then
				{
					throw [["player", format["`%1` is already dead", _targetUID]]];
				};

				// Death logging
				if ((getNumber (configFile >> "CfgSettings" >> "Logging" >> "deathLogging")) isEqualTo 1) then
				{
					ESM_DatabaseExtension callExtension format[
						"1:DEATH:%1",
						format[
							"%1 was killed by %2 via Exile Server Manager",
							_playerData select 1,	// name
							_targetUID
						]
					];
				};

				// Create new record in the history
				format[
					"insertPlayerHistory:%1:%2:%3:%4:%5",
					_targetUID,
					_playerData select 1,  	// name
					_playerData select 11, 	// position_x
					_playerData select 12, 	// position_y
					_playerData select 13  	// position_z
				] call ExileServer_system_database_query_fireAndForget;

				// Delete the player record
				format[
					"deletePlayer:%1",
					_playerData select 0  	// uid
				] call ExileServer_system_database_query_fireAndForget;
			};

			_logDescription = localize!("Player_Log_Description_Kill");
		};

		default
		{
			throw [["player", format["`%1` is not a valid type", _action]]];
		};
	};

	//////////////////////
	// Completion
	//////////////////////
	[
		// Response
		[_id, _response],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Player_Log_Title")],
				["description", _logDescription],
				["color", "green"],
				["fields", [
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
