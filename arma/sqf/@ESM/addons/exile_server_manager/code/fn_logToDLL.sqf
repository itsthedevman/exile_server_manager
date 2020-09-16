/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Logs a message to the DLL
*/

params ["_message", ["_type", "info"]];
["dll_log", [["message", _message call ExileClient_util_string_escapeJson], ["type", _type]]] call ESM_fnc_callExtension;