/* ----------------------------------------------------------------------------
Function: ESMs_util_array_all

Description:
	Passes each element of the array to the given code block

Parameters:
	_this select 0 	- The array to iterate over. [Array]
	_this select 1 	- The code block to execute for each element [Code]

Returns:


Examples:
	(begin example)

	private _a = [1,2,3,4,5];
	[_a, { _this > 0 }] call ESMs_util_array_all; // -> true
	[_a, { _this < 0 }] call ESMs_util_array_all; // -> false

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

(
	{
		if (isNil "_x") then
		{
			// I would like to formally lodge a compliant about nil. k thx
			nil call (_this select 1)
		}
		else
		{
			_x call (_this select 1)
		}
	}
	count (_this select 0)
)
isEqualTo count(_this select 0)
