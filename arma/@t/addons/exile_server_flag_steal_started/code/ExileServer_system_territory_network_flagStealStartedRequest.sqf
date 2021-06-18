/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		XM8 Notification for when a flag is being stolen
*/

_sessionID = _this select 0;
_parameters = _this select 1;
_flag = _parameters select 0;

try
{
	_playerObject = _sessionID call ExileServer_system_session_getPlayerObject;

	if (isNull _playerObject) then
	{
		throw "Player Object NULL";
	};

	if ((_flag getVariable ["ExileFlagStolen", 0]) isEqualTo 1) then 
	{
		throw "Flag already stolen!";
	};
	
	if ((_playerObject distance2D _flag) > 5) then
	{
		throw format["%1 (%2) Attempted to steal a flag that wasn't near them", name _playerObject, getPlayerUID _playerObject];
	};

	_serverTime = time;
	if (_serverTime > ((_flag getVariable ["ExileXM8MobileNotifiedTime",-1800]) + 1800)) then
	{
		_flag call ExileServer_system_xm8_sendFlagStealStarted;
		_flag setVariable ["ExileXM8MobileNotifiedTime", _serverTime];
	};
}
catch
{
	["ExileServer_system_territory_network_flagStealStartedRequest", _exception] call ESM_fnc_log;
};

true