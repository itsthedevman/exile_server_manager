/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Retrieves variables from the server to be used here
*/

{
	private _variableName = _x select 0;
	private _value = _x select 1;

	["fn_postServerInitialization", format["Binding value %1 (%2) to %3", _value, typeName(_value), _variableName]] call ESM_fnc_log;
	missionNameSpace setVariable [_variableName, _value];
}
forEach _this;

ESM_DatabaseVersion = format["extDB%1", ESM_ExtDBVersion];
ESM_Initialized = true;

["fn_postServerInitialization", "ESM has been initalized successfully"] call ESM_fnc_log;
