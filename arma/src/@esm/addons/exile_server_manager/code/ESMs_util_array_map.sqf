/* ----------------------------------------------------------------------------
Function:
	ESMs_util_array_map

Description:
	Iterates over the provided array and returns a new array containing the result of calling the provided function on each item in the array

Parameters:
	_input - [Array] The array to iterate over
	_function - [Code] The code to execute on each item in the provided array

Returns:
	An new array containing the results

Examples:
	(begin example)

	[[1,2,3,4,5], { _this * 2 }] call ESMs_util_array_map; // Returns [2,4,6,8,10]

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _input = _this select 0;
private _function = _this select 1;
private _output = [];

{
	private _result = nil;
	if (nil?(_x)) then
	{
		// Arma strikes again. `nil call Function` is ignored and does not execute
		_result = scriptNull call _function;
	}
	else
	{
		_result = _x call _function;
	};

	if (nil?(_result)) then
	{
		// https://community.bistudio.com/wiki/pushBack See DreadedEntity's comment
		_output set [_forEachIndex, nil];
	}
	else
	{
		_output pushBack _result;
	};
}
forEach _input;

_output
