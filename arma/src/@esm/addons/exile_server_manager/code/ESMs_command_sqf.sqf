/* ----------------------------------------------------------------------------
Function: ESMs_command_sqf

Description:
	Executes the provided SQF on the target (server, all players, or a single player).
	Called from ESMs_system_extension_callback as part of a command workflow.
	Do not call manually unless you know what you're doing!

Parameters:
	_this  -  A hashmap representation of a ESM message [Hashmap]

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
	execute_on: String. Valid options: "server", "all", "player"
	code: String
*/
private _data = get!(_this, "data");

/*
	player: HashMap
		steam_uid: String,
		discord_id: String,
		discord_name: String,
		discord_mention: String,
	target: HashMap | Nothing
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
private _loggingEnabled = ESM_Logging_Exec;

private _code = compile(get!(_data, "code"));
private _result = nil;

try
{
	//////////////////////
	// Execution
	//////////////////////
	switch (get!(_data, "execute_on")) do
	{
		case "all":
		{
			_code remoteExec ["call", -2];
		};

		case "server":
		{
			_result = call _code;
		};

		default
		{
			private _targetUID = dig!(_metadata, "target", "steam_uid");
			private _targetObject = _targetUID call ExileClient_util_player_objectFromPlayerUID;

			if (isNull _targetObject) then
			{
				private _playerMention = dig!(_metadata, "player", "discord_mention");
				private _targetMention = dig!(_metadata, "target", "discord_mention");

				throw [
					["player", localize!("TargetNeedsToJoin", _playerMention, _targetMention, ESM_ServerID)]
				];
			};

			_code remoteExec ["call", owner _targetObject];
		};
	};

	//////////////////////
	// Validation
	//////////////////////
	// Result _must_ be a string
	if (!nil?(_result) && { !type?(_result, STRING) }) then
	{
		_result = str(_result);
	};

	//////////////////////
	// Completion
	//////////////////////
	[
		// Response
		[
			_id,
			[["result", returns_nil!(_result)]]
		],

		// Log the following?
		_loggingEnabled,
		{
			[
				["title", localize!("Success")],
				["description", [
					["code", str(_code)],
					["result", returns_nil!(_result)]
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
