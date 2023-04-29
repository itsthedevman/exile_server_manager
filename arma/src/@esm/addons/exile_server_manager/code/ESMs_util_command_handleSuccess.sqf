/* ----------------------------------------------------------------------------
Function:
	ESMs_util_command_handleSuccess

Description:
	Helps handle logging a command success

Parameters:
	_response - [Array] The response to be sent back to the bot. See ESMs_system_message_respond_to for syntax
	_logMessage - [String, Array] The message to log. See ESMs_util_embed_create for Array syntax
	_condition - [Boolean] Should this log be sent?

Returns:
	Nothing

Examples:
	(begin example)

		// Logs a string
		[[_id], ESM_Logging_AddPlayerToTerritory, "Player added!"] call ESMs_util_command_handleSuccess;

		// Logs an embed
		[[_id], true, [
			["title", "This is a title"],
			["color", "green"]
		]] call ESMs_util_command_handleSuccess

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2023 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

(_this select 0) call ESMs_system_message_respond_to;

if !(_this select 1) exitWith {};

private _logMessage = _this param [2, []];

if (type?(_logMessage, ARRAY)) then
{
	_logMessage = _logMessage call ESMs_util_embed_create;
};

_logMessage call ESMs_system_network_discord_log;
nil
