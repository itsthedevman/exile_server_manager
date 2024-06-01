/* ----------------------------------------------------------------------------
Function:
	ESMs_util_number_toString

Description:
	Converts a scalar to a string and makes it look pretty

Parameters:
	_this - [Scalar] The number to convert to a string

Returns:
	Nothing

Examples:
	(begin example)

		19993 call ESMs_util_number_toString; // "19,993"

	(end)

Author:
	Permission given by Andrew_S90 for use within Exile Server Manager
	© 2018-current_year!() Andrew_S90

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _input = _this;
private _output = [];
private _isNegative = _input < 0;

if (_isNegative) then
{
	_input = abs(_input);
};

private _popTabsString = _input call ExileClient_util_string_exponentToString;
private _split = _popTabsString splitString "";
reverse _split;

{
	if (((_forEachIndex % 3) isEqualTo 0) && !(_forEachIndex isEqualTo 0)) then
	{
		_output pushBack ",";
	};
	_output pushBack _x;
}
forEach _split;

reverse _output;

_output = _output joinString "";

if (_isNegative) then
{
	format["-%1", _output]
}
else
{
	_output
};
