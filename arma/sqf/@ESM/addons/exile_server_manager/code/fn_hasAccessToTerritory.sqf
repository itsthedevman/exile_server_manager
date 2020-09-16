/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Checks if the playerUID has AT LEAST a certain access. 
*/

private _flagObject = _this select 0;
private _playerUID = _this select 1;
private _minimumAccessLevel = param [2, "build"];
private _hasAccess = false;

if (_playerUID in ESM_TerritoryManagementUIDs) exitWith { true };

switch (toLower(_minimumAccessLevel)) do 
{
	case "moderator":
	{
		_moderators = _flagObject getVariable ["ExileTerritoryModerators", []];
		if (_playerUID in _moderators) then
		{
			_hasAccess = true;
		};
	};
	
	case "owner":
	{
		_owner = _flagObject getVariable ["ExileOwnerUID", ""];
		if (_owner isEqualTo _playerUID) then 
		{
			_hasAccess = true;
		};
	};
	
	default
	{
		_buildRights = _flagObject getVariable ["ExileTerritoryBuildRights", []];
		if (_playerUID in _buildRights) then
		{
			_hasAccess = true;
		};
	};
};

_hasAccess