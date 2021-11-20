
/**
 *
 * Function:
 *      ESMs_system_sqf_execute
 *
 * Description:
 *      Executes the provided SQF on the target (server, all players, or a single player)
 *
 * Arguments:
 *      _this	-	A hashmap representation of a Message
 *
 * Examples:
 *      Message call ESMs_system_sqf_execute;
 *
 * * *
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 Bryan "WolfkillArcadia"
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 *
 **/

private _id = _this getOrDefault ["id", nil];

/*
	target_type: String,
	code: String
*/
private _data = _this getOrDefault ["data", nil];

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
private _metadata = _this getOrDefault ["metadata", nil];
if (isNil "_id" || { isNil "_data" } || { isNil "_metadata" }) exitWith { nil };

private _type = [_data, "execute_on"] call ESMs_util_hashmap_get;
private _code = [_data, "code"] call ESMs_util_hashmap_get;
private _result = nil;

_code = compile _code;

switch (_type) do
{
	case "all":
	{
		_code remoteExec ["call", -2];
	};

	case "server":
	{
		_result = str(call _code);
	};

	default
	{
		private _targetUID = [_metadata, "target", "steam_uid"] call ESMs_util_hashmap_get;
		private _targetObject = _targetUID call ExileClient_util_player_objectFromPlayerUID;

		if (isNull _targetObject) exitWith
		{
			[_id, format[localize "$STR_ESM_SqfExecute_NullPlayer", _playerMention, _targetUID, ESM_ServerID]] call ESMs_object_message_respond_withError;
		};

		_code remoteExec ["call", owner _targetObject];
	};
};

[_id, "arma", "sqf_result", [["result", _result]]] call ESMs_object_message_respond_to;

nil
