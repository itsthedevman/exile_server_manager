/* ----------------------------------------------------------------------------
Function:
	ESMs_util_command_handleException

Description:
	Handles a command exception by logging and replying to the inbound message

Parameters:
	_id - [String] The inbound message's ID
	_commandException - [HashMap] The contents of the exception
	_callingFunction - [String] The SQF function that called this function
	_log - [true/false] Should this trigger a log to the discord channel?

Returns:
	Nothing

Examples:
	(begin example)

		[
			_id,
			_exception,
			"ESMs_command_add",
			ESM_Logging_AddPlayerToTerritory
		]
		call ESMs_util_command_handleException;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2023 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _id = _this select 0;
private _commandException = _this select 1;
private _callingFunction = _this select 2;
private	_log = param [3, false];

private _exceptionHash = _commandException call ESMs_util_hashmap_fromArray;

// Message to the admins
if (key?(_exceptionHash, "admin")) then
{
	private _message = get!(_exceptionHash, "admin", "");

	warn!(_message);

	if (_log) then
	{
		private _embed = [["description", _message]] call ESMs_util_embed_create;
		[_embed, "Server", format["`%1`", ESM_ServerID], true] call ESMs_util_embed_addField;
		[_embed, "Function", _callingFunction, true] call ESMs_util_embed_addField;

		[_id, _embed] call ESMs_system_network_discord_log;
	};
};

// Message to the player
if (key?(_exceptionHash, "player")) then
{
	private _message = get!(_exceptionHash, "player", "");
	[_id, _message] call ESMs_system_message_respond_withError;
};

nil
