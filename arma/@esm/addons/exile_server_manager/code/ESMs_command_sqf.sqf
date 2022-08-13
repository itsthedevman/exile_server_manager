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
	© 2018-2022 Bryan "WolfkillArcadia"

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

try
{
	private _type = [_data, "execute_on"] call ESMs_util_hashmap_get;
	private _code = compile ([_data, "code"] call ESMs_util_hashmap_get);
	private _result = nil;

	switch (_type) do
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
			private _targetUID = [_metadata, "target", "steam_uid"] call ESMs_util_hashmap_get;
			private _targetMention = [_metadata, "target", "discord_mention"] call ESMs_util_hashmap_get;
			private _targetObject = _targetUID call ExileClient_util_player_objectFromPlayerUID;

			if (isNull _targetObject) then
			{
				throw format[localize "$STR_ESM_Sqf_NullTarget", _targetMention, _targetUID, ESM_ServerID];
			};

			_code remoteExec ["call", owner _targetObject];
		};
	};

	// // It becomes difficult to handle while parsing if there are multiple layers of quotes
	// if (!(isNil "_result") && { !(_result isEqualType "") }) then
	// {
	// 	_result = str(_result);
	// };

	[
		_id,
		"arma",
		"sqf_result",
		[
			["result", if (isNil "_result") then { nil } else { _result }]
		]
	]
	spawn ESMs_object_message_respond_to;
}
catch
{
	[_id, _exception] spawn ESMs_object_message_respond_withError;
};

nil
