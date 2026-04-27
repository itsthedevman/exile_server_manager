/* ----------------------------------------------------------------------------
Function:
	ESMs_util_number_toString

Description:
	Converts an Scalar to a localized number

Parameters:
	_this - [Scalar] The number to convert

Returns:
	The formatted string

Examples:
	(begin example)

		1999 call ESMs_util_number_toString; // "1,999"
		1234e007 call ESMs_util_number_toString; // "12,340,000,000"

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"
	© 2018-current_year!() Andrew_S90

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _input = _this;
private _isNegative = _input < 0;

if (_isNegative) then
{
	_input = abs(_input);
};

private _output = [
	"number_to_string",
	_input call ExileClient_util_string_exponentToString
]
call ESMs_system_extension_call;

if (_isNegative) then
{
	_output = format ["-%1", _output];
};

_output
