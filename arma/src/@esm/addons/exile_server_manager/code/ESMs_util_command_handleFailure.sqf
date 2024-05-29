/* ----------------------------------------------------------------------------
Function:
	ESMs_util_command_handleFailure

Description:
	Handles a command failure by logging and replying to the inbound message

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
		call ESMs_util_command_handleFailure;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _id = _this select 0;
private _commandException = _this select 1;
private _callingFunction = _this select 2;
private	_log = _this param [3, false];

private _exceptionHash = createHashmapFromArray _commandException;

// Message to the player
if (key?(_exceptionHash, "player")) then
{
	private _message = get!(_exceptionHash, "player", "");
	[_id, _message] call ESMs_system_message_respond_withError;
};

// Message to the admins
if (key?(_exceptionHash, "admin")) then
{
	private _message = get!(_exceptionHash, "admin", "");
	warn!(_message);

	if (_log) then
	{
		if (type?(_message, ARRAY)) then
		{
			_message = _message call ESMs_util_embed_create;
		};

		_message call ESMs_system_network_discord_log;
	};
};

nil
