/* ----------------------------------------------------------------------------
Function: ESMs_system_extension_callback

Description:
	Processes a SQF function call from the extension

Parameters:
	_functionName 	- The name of the function to be called [String]
	_data 			- The data to be passed to the function [Any]

Returns:
	true

Examples:
	(begin example)

	["ESMs_util_log", ["extension", "This is how the extension calls functions"]] call ESMs_system_extension_callback;
	["ESMs_system_command_sqf", "[[""id"",""data"",""metadata""], [...]]] call ESMs_system_extension_callback;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */


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

private _response = _data call ESMs_system_extension_processResult;
if (_response isEqualType HASH_TYPE && { "id" in _response }) then
{
	private _id = _response getOrDefault ["id", ""];
	private _data = _response getOrDefault ["data", ""];
	private _metadata = _response getOrDefault ["metadata", ""];

	{
		["callback", _x] call ESMs_util_log;
	}
	forEach
	[
		format["Executing ""%1""", _functionName],
		format["    ID (%1): %2", typeName _id, _id],
		format["    DATA (%1): %2", typeName _data, _data],
		format["    METADATA (%1): %2", typeName _metadata, _metadata]
	];
}
else
{
	["callback", format["Calling function ""%1"" with %2", _functionName, _response]] call ESMs_util_log;
};

_response call _function;

true
