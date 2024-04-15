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
	["ESMs_command_sqf", "[[""id"",""data"",""metadata""], [...]]] call ESMs_system_extension_callback;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

// This function is scheduled by default
private _functionName = _this select 0;
private _data = _this select 1;

// Make sure the function is compiled
private _function = missionNameSpace getVariable [_functionName, ""];
if (type?(_function, STRING)) exitWith
{
	error!("Attempted to call function '%1' but it was not defined. Associated data: %2", _functionName, _data);
};

private _arguments = _data call ESMs_system_extension_processResult;
// debug!("%1 call %2;", _arguments, _functionName);

_arguments call _function; // Do not use spawn

true
