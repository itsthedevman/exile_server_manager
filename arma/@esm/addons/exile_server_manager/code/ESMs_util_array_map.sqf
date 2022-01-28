/**
 *
 * Function:
 *      ESMs_util_array_map
 *
 * Description:
 *      Functions like most map functions. Iterates over the provided array and returns a new array containing the result
 * 		of calling the provided function on each item in the array
 *
 * Arguments:
 *      _this select 0 - Array - The array to iterate over
 *		_this select 1 - Code  - The code to execute on each item in the provided array
 *
 * Examples:
 *      [[1,2,3,4,5], { _this * 2 }] call ESMs_util_array_map; // -> [2,4,6,8,10]
 *
 * * *
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 Bryan "WolfkillArcadia"
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 *
 **/

private _output = [];

{
	_output pushBack (_x call (_this select 1));
}
forEach (_this select 0);

_output
