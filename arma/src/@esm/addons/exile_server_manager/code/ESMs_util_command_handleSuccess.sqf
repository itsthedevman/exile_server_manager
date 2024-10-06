/* ----------------------------------------------------------------------------
Function:
	ESMs_util_command_handleSuccess

Description:
	Helps handle logging a command success

Parameters:
	_response - [Array] The response to be sent back to the bot.
						See ESMs_system_message_respond_to for syntax
	_condition - [Boolean] Should this log be sent?
	_logMessage - [Code] A code block containing the message to log.
						This is a code block to save performance if the condition is false
						The code block must return either be a String or Array
						See ESMs_util_embed_create for Array syntax

Returns:
	Nothing

Examples:
	(begin example)

		// Logs a string
		[
			[_id],
			ESM_Logging_CommandAdd,
			{ "Player added!" }
		] call ESMs_util_command_handleSuccess;

		// Logs an embed
		[
			[_id],
			true,
			{
				[
					["title", "This is a title"],
					["color", "green"]
				]
			}
		] call ESMs_util_command_handleSuccess

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _message = _this select 0;
[_message select 0, "ack", _message select 1] call ESMs_system_message_respond_to;

if !(_this select 1) exitWith {};

private _logContent = call (_this param [2, {}]);

if (type?(_logContent, ARRAY)) then
{
	_logContent = _logContent call ESMs_util_embed_create;
};

_logContent call ESMs_system_network_discord_log;
nil
