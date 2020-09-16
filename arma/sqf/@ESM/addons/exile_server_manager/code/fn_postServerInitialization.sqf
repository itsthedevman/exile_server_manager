/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Retrieves variables from the server to be used here
*/

// Remove the temp thread
if !(ESM_Initialized) then 
{
	[ESM_RequestThread] call ExileServer_system_thread_removeTask;
};

_return = _this select [2, count(_this) - 1];

{
	private _value = "";
	switch (_x select 1) do
	{
		case "BOOL":
		{
			_value = (_return select _forEachIndex) isEqualTo "true";
		};
		case "SCALAR":
		{
			_value = parseNumber(_return select _forEachIndex);
		};
		case "ARRAY":
		{
			_value = parseSimpleArray(_return select _forEachIndex);
		};
		default
		{
			_value = _return select _forEachIndex;
		};
	};

	["fn_postServerInitialization", format["Binding value %1 (%2) to %3", _value, typeName(_value), _x select 0]] call ESM_fnc_log;
	missionNameSpace setVariable [_x select 0, _value];
}
forEach (getArray(configFile >> "CfgESM" >> "globalVariables"));

if !(ESM_Initialized) then 
{
	if (ESM_UseExileThreading) then
	{
		[] spawn 
		{
			waitUntil {PublicServerIsLoaded};
			[ESM_ThreadDelay, ESM_fnc_checkForRequests, [], true] call ExileServer_system_thread_addTask;
		};
	}
	else
	{
		[] spawn 
		{
			waitUntil {PublicServerIsLoaded};
			while {true} do
			{
				call ESM_fnc_checkForRequests;
				uiSleep ESM_ThreadDelay;
			};
		};
	};
};

ESM_DatabaseVersion = if (ESM_UseExtDB3) then { "extDB3" } else { "extDB2" };
ESM_Initialized = true;

["fn_postServerInitialization", "ESM has been initalized successfully"] call ESM_fnc_log;