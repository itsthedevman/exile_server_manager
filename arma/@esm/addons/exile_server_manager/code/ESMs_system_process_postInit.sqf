/**
 * ESM_system_process_postInit
 * 	Initiated from a system message from the bot after it finalizes the connection.
 *  Loads any global variables
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 WolfkillArcadia
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 */

["postInit", _this] call ESMs_util_log;
{
	private _variableName = _x select 0;
	private _value = _x select 1;

	["postInit", format["Binding value %1 (%2) to %3", _value, typeName(_value), _variableName]] call ESMs_util_log;
	missionNameSpace setVariable [_variableName, _value];
}
forEach _this;

ESM_DatabaseVersion = format["extDB%1", ESM_ExtDBVersion];
ESM_Initialized = true;

["postInit", "Initialized and connected to the bot"] call ESMs_util_log;
