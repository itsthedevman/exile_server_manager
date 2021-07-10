/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Executes code on the server or a client
*/

params ["_commandID", "_authorInfo", "_target", "_code"];
(parseSimpleArray(_authorInfo)) params ["_authorTag", "_authorID"];
private _playerObject = objNull;

if !(ESM_AllowRemoteExec) exitWith {};

try 
{
	if (_target isEqualTo "server") then 
	{
		_return = call compile _code;
		if (!isNil "_return") then 
		{
			[_commandID, [["message", format["Executed on server successfully. Returned: ```%1```", str(_return) call ExileClient_util_string_escapeJson]]]] call ESM_fnc_respond;
		}
		else
		{
			[_commandID, [["message", "Executed code on server"]]] call ESM_fnc_respond;
		};
	}
	else
	{
		_playerObject = _target call ExileClient_util_player_objectFromPlayerUID;
		
		if (isNull _playerObject) then 
		{
			throw "Invalid target or target is not online";
		};

		(compile _code) remoteExec ["call", owner _playerObject];

		[_commandID, [["message", "Executed code on target"]]] call ESM_fnc_respond;
	};
}
catch 
{
	[_commandID, [["message", _exception]]] call ESM_fnc_respond;
};
