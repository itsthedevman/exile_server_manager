/* ----------------------------------------------------------------------------
Function:
	ESMs_command_gamble

Description:
	Gamble some poptabs! Nothing wrong in that... ;)

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
  amount: Integer
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
private _loggingEnabled = ESM_Logging_CommandGamble;

private _amountToGamble = get!(_data, "amount");

private _playerMetadata = get!(_metadata, "player");

private _playerUID = get!(_playerMetadata, "steam_uid");
private _playerMention = get!(_playerMetadata, "discord_mention");

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

	// If the player is online make sure to adjust their in-game data
	// Otherwise, we'll get their poptabs from the database itself
	private _playerObject = _playerUID call ExileClient_util_player_objectFromPlayerUID;
	private _lockerBefore = if (null?(_playerObject)) then
	{
		format[
			"getLocker:%1",
			_playerUID
		] call ExileServer_system_database_query_selectSingleField;
	}
	else
	{
		_playerObject getVariable ["ExileLocker", 0];
	};

	// Determine how much the player is gambling
	_amountToGamble = switch (_amountToGamble) do
	{
		case "all":
		{
			_lockerBefore;
		};

		case "half":
		{
			round(_lockerBefore / 2);
		};

		default
		{
			round(parseNumber(_amountToGamble));
		};
	};

	// Player must gamble at least 1 poptab
	// abs just in case
	if (abs(_amountToGamble) isEqualTo 0) then
	{
		throw [["player", localize!("Gamble_CannotGambleNothing", _playerMention)]];
	};

	// Player must have enough poptabs
	if (_amountToGamble > _lockerBefore) then
	{
		throw [["player", localize!("TooPoor", _playerMention)]];
	};

	// If check is enabled, player must not have a full locker
	private _maxDeposit = getNumber(missionConfigFile >> "CfgLocker" >> "maxDeposit");
	if (ESM_Gambling_LockerLimitEnabled && { _lockerBefore >= _maxDeposit }) then
	{
		throw [["player", localize!("Gamble_LockerFull", _playerMention)]];
	};

	//////////////////////
	// Modification
	//////////////////////

	private _amountChanged = _amountToGamble;
	private _lockerAfter = _lockerBefore;
	private _areYaWinningSon = random(1) < ESM_Gambling_WinPercentage;
	private _responseTitle = "";
	private _responseDescription = "";

	if (_areYaWinningSon) then
	{
		// Calculate the win multiplier
		private _winMultiplier = (
			// Generate a random value from the payout randomizer array
			random(ESM_Gambling_PayoutRandomizer) *

			// Multiply by the payout modifier (base percentage)
			ESM_Gambling_PayoutModifier +

			// Add the flat modifier to adjust the final multiplier
			ESM_Gambling_Modifier
		);

		// Calculate the final payout
		// This ensures the player always gets back at least their original bet (1x)
		// plus any additional winnings determined by the win multiplier
		_amountChanged = round(_amountToGamble * (1 + _winMultiplier));

		// Give them their winnings
		_lockerAfter = _lockerBefore + _amountChanged;

		// Impose the limit if there is one
		if (ESM_Gambling_LockerLimitEnabled && { _lockerAfter > _maxDeposit }) then
		{
			// Set the locker to the max
			_lockerAfter = _maxDeposit;

			_responseDescription = format[
				localize!("Gambling_Response_Description_WinMaxLocker"),
				_playerMention,
				_amountToGamble call ESMs_util_number_toString,
				_amountChanged call ESMs_util_number_toString,
				(_amountChanged - _amountToGamble) call ESMs_util_number_toString,
				_lockerAfter call ESMs_util_number_toString
			];
		}
		else
		{
			_responseDescription = format[
				localize!("Gambling_Response_Description_Win"),
				_playerMention,
				_amountToGamble call ESMs_util_number_toString,
				_amountChanged call ESMs_util_number_toString,
				(_amountChanged - _amountToGamble) call ESMs_util_number_toString,
				_lockerAfter call ESMs_util_number_toString
			];
		};

		_responseTitle = localize!("Gamble_Response_Title_Win");
	}
	else
	{
		// They lost. lol
		_lockerAfter = _lockerBefore - _amountToGamble;

		// There are 5 loss messages to pick from
		_responseDescription = format[
			localize(format[
				"$STR_ESM_Gambling_Response_Description_Loss_%1",
				1 + (floor(random(5))) // 1 through 5
			]),
			_playerMention,
			_amountToGamble call ESMs_util_number_toString,
			_lockerAfter call ESMs_util_number_toString
		];

		_responseTitle = localize!("Gamble_Response_Title_Loss");
	};

	// If the player is online, update their locker amount
	if !(null?(_playerObject)) then
	{
		_playerObject setVariable ["ExileLocker", _lockerAfter, true];
	};

	// And update the database
	format[
		"updateLocker:%1:%2",
		_lockerAfter,
		_playerUID
	]
	call ExileServer_system_database_query_fireAndForget;

	//////////////////////
	// Completion
	//////////////////////

	// Tell ESM
	[
		// Response
		[
			_id,
			[
				["win", _areYaWinningSon],
				["amount", _amountChanged],
				[
					"response",
					[
						["author", localize!("ResponseAuthor", ESM_ServerID)],
						["title", _responseTitle],
						["description", _responseDescription]
					]
				]
			]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Gamble_Log_Title")],
				[
					"description",
					format [
						localize!("Gamble_Log_Description"),
						if (_areYaWinningSon) then { "won" } else { "lost" }
					]
				],
				["color", "green"],
				["fields", [
					[localize!("Player"), _playerMetadata, true],
					[localize!("LockerBefore"), _lockerBefore call ESMs_util_number_toString, true],
					[localize!("LockerAfter"), _lockerAfter call ESMs_util_number_toString, true]
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
