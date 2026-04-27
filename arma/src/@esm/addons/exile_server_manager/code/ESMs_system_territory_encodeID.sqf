/* ----------------------------------------------------------------------------
Function:
	ESMs_system_territory_encodeID

Description:
	Encodes the provided territory's database ID for public viewing

Parameters:
	_this - [Object] The territory flag

Returns:
	Nothing

Examples:
	(begin example)

		_territory call ESMs_system_territory_encodeID;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

["encode_territory_id", _this getVariable ["ExileDatabaseID", -1]] call ESMs_system_extension_call
