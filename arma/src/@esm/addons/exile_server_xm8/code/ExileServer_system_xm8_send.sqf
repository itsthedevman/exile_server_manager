/**
 * ExileServer_system_xm8_send
 *
 * Exile Mod
 * www.exilemod.com
 * © 2015 Exile Mod Team
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.
 *
 * Modify by Exile Server Manager Team for use with Exile Server Manager
 */
 
private["_methodName", "_recipients", "_text", "_allowedMethods", "_escapedText", "_message", "_result"];
_methodName = _this select 0;
_recipients = _this select 1;
_text = _this select 2;
_flagID = param [3, ""];
try 
{
	if !(_recipients isEqualType []) then 
	{
		throw "Broken recipient list!";
	};
	_recipients = _recipients call ExileClient_util_array_unique;
	if ((count _recipients) isEqualTo 0) then 
	{
		throw "No recipients!";
	};
	if ((count _recipients) > 30) then 
	{
		throw "Too many recipients!";
	};
	_escapedText = _text call ExileClient_util_string_escapeJson;
	if (_escapedText isEqualTo "") then 
	{
		throw "Invalid text!";
	};
	["xm8_notification", [["type", _methodName], ["recipients", format['{ "r": %1 }', _recipients] call ExileClient_util_string_escapeJson], ["message", _escapedText], ["id", _flagID]]] call ESM_fnc_callExtension;
	["xm8_send", format["XM8 notification sent. Type: %1. Recipients: %2. Message: %3", _methodName, _recipients, _escapedText]] call ESM_fnc_log;
}
catch 
{
	format ["XM8 message failed: %1", _exception] call ExileServer_util_log;
};