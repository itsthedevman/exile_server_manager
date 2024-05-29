/**
 *
 * Function:
 *      ESMs_system_message_respond_withError
 *
 * Description:
 *		Responds to a message with the provided error.
 *
 * Arguments:
 *      _id 	- The ID of the message to respond to
 *		_error	- The error message to send back
 *
 * Examples:
 *      [_id, "Error Message"] call ESMs_system_message_respond_withError;
 *
 * * *
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-current_year!() Bryan "WolfkillArcadia"
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 *
 **/

private _id = _this select 0;
private _errorMessage = _this select 1;

if (empty?(_errorMessage)) exitWith {};

[_id, "call", [], [], [["message", _errorMessage]]] call ESMs_system_message_respond_to
