/* ----------------------------------------------------------------------------
Function:
	ESMs_system_territory_checkAccess

Description:
	Check if a player has access to a territory. A minimum access level can be provided for fine grain control

Parameters:
	_this select 0	- The flag object to check
	_this select 1 	- The player's UID to check
	_this select 2 	- The minimum access level the player must have.
					  Defaults to: "builder"
					  Valid options: "builder", "moderator", "owner"

Returns:
	true, false

Examples:
	(begin example)

	// Returns true if the player, at the very least, has build rights
	[_flagObject, _playerUID] call ESMs_system_territory_checkAccess;

	// Returns true if the player has moderator access, or is the owner
	[_flagObject, _playerUID, "moderator"] call ESMs_system_territory_checkAccess;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _flagObject = _this select 0;
private _playerUID = _this select 1;

// Territory admins can view any territory
if (_playerUID in ESM_TerritoryAdminUIDs) exitWith { true };

// Default value does not matter
private _minimumAccessLevel = param [2, ""];
switch (toLower(_minimumAccessLevel)) do
{
	case "moderator":
	{
		private _moderators = _flagObject getVariable ["ExileTerritoryModerators", []];
		_playerUID in _moderators
	};

	case "owner":
	{
		private _owner = _flagObject getVariable ["ExileOwnerUID", ""];
		_owner isEqualTo _playerUID
	};

	default
	{
		private _buildRights = _flagObject getVariable ["ExileTerritoryBuildRights", []];
		_playerUID in _buildRights
	};
}
