/* ----------------------------------------------------------------------------
Function: ESMs_util_array_isValidHashmap

Description:
	Checks to see if an array can be converted to a hashmap

Parameters:
	_this - Any value to check

Returns:
	true if it is valid
	false if it not

Examples:
	(begin example)

	[["key", "value"]] call ESMs_util_array_isValidHashmap; // true
	[["key"], ["value"]] call ESMs_util_array_isValidHashmap; // false
	"key" call ESMs_util_array_isValidHashmap // false

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */


if (isNil "_this") exitWith { false };

type?(_this, ARRAY) && {
	[
		_this,
		{
			// _this represents a single key/value pair
			type?(_this, ARRAY) && {
				// Must have a key and a value
				count(_this) isEqualTo 2 && {
					// The key must be a string
					type?((_this select 0), STRING)
				}
			}
		}
	]
	call ESMs_util_array_all
}
