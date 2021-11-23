/**
 *
 * Function:
 *      ESMs_system_extension_callback
 *
 * Description:
 *      Facilitates a SQF function call from the extension
 *
 * Arguments:
 *      _functionName	-	The name of the function to be called as a string.
 *		_data			-	The data to be passed to the function
 *
 * Examples:
 *      ["ESMs_util_log", ["extension", "This is how the extension calls functions"]] call ESMs_system_extension_callback;
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

private _functionName = _this select 0;
private _data = _this select 1;

// Make sure the function is compiled
private _function = missionNameSpace getVariable [_functionName, ""];
if (_function isEqualTo "") exitWith
{
	[
		"callback",
		format["Attempted to call function '%1' but it was not defined. Associated data: %2", _functionName, _data],
		"error"
	] call ESMs_util_log;
};

private _result = _data call ESMs_system_extension_processResult;
private _message = _result call ESMs_util_hashmap_fromArray;

["callback", format["Calling ""%1"" with %2", _functionName, _message], "debug"] call ESMs_util_log;
["callback", format["Executing ""%1"" with message ""%2""", _functionName, _message get "id"]] call ESMs_util_log;

_message call _function;

true
