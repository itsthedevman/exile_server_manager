/* ----------------------------------------------------------------------------
Function:
	ESMs_system_territory_get

Description:
	Retrieves a flag object via its ExileDatabaseID

Parameters:
	_this  -  The ExileDatabaseID to search for

Returns:
	A flag object, objNull

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _flagObject = objNull;

{
	if ((_x getVariable ["ExileDatabaseID", -1]) isEqualTo _this) then
	{
		_flagObject = _x;
		break;
	};
}
forEach ("Exile_Construction_Flag_Static" allObjects 0); // Much faster than allMissionObjects

_flagObject
