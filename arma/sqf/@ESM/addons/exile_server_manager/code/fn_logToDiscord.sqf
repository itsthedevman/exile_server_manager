/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Logs a message to discord
*/

private _types = ["info","success","warn","error"];
private _templates = ["message", "embed"];

private _type = toLower(_this select 0);
private _template = toLower(_this select 1);
private _parameters = _this select 2;

if !(_type in _types) exitWith
{
	["fn_logToDiscord", format["Invalid type %1", _type]] call ESM_fnc_log;
};

if !(_template in _templates) exitWith
{
	["fn_logToDiscord", format["Invalid template %1", _template]] call ESM_fnc_log;
};

private _package = [["type", _type],["template", _template]];

switch (_template) do 
{
	case "message":
	{
		_package pushBack ["message", _parameters select 0];
	};
	
	case "embed":
	{
		_package pushBack ["embed", _parameters];
	};
};

["discord_log", _package] call ESM_fnc_callExtension