/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		XM8 Notification for a custom message.
*/
_recipients = _this select 0;
_title = param [1, ""];
_body = param [2, ""];
if (_title isEqualTo "" || _body isEqualTo "") exitWith 
{
	["ExileServer_system_xm8_sendCustom", "The title or body of the message cannot be blank!"] call ESM_fnc_log;
};
["custom", _recipients, format['{ "title": "%1", "body": "%2" }', _title, _body]] call ExileServer_system_xm8_send;