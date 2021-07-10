/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Gets the flag object in game from it's ID. Returns null if it doesn't exist
*/

// Loop through all the flags and get the flag
private _flagObject = objNull;
private _flagID = if (_this isEqualType "") then { parseNumber(_this) } else { _this };

{
	if ((_x getVariable ["ExileDatabaseID", -1]) isEqualTo _flagID) then 
	{
		_flagObject = _x;
	};
	false
}
count (allMissionObjects "Exile_Construction_Flag_Static");

_flagObject