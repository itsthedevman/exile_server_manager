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

private _functionName = _this select 0;
private _data = _this select 1;

// Make sure the function is compiled
private _function = missionNameSpace getVariable [_functionName, ""];
if (type?(_function, STRING)) exitWith
{
	error!("Attempted to call function '%1' but it was not defined. Associated data: %2", _functionName, _data);
};

private _response = _data call ESMs_system_extension_processResult;
_response spawn _function;

if (debug?) then
{
	if (type?(_response, HASH) && { "id" in _response }) then
	{
		private _id = get!(_response, "id", "");
		private _data = get!(_response, "data", "");
		private _metadata = get!(_response, "metadata", "");

		debug!("Spawned ""%1""", _functionName);
		debug!("- Id (%1): %2", typeName _id, _id);
		debug!("- Data (%1): %2", typeName _data, _data);
		debug!("- Metadata (%1): %2", typeName _metadata, _metadata);
	}
	else
	{
		debug!("Spawned function ""%1"" with %2", _functionName, _response);
	};
};

true
