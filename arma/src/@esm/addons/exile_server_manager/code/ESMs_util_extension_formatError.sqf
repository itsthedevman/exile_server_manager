/* ----------------------------------------------------------------------------
Function:
	ESMs_util_extension_formatError

Description:
	Formats the following error codes into a human readable string
	Possible error codes:
		1 	Command not found
		2x 	Invalid argument count, x is received count
		3x 	Invalid argument type, x is argument position
		4 	Attempted to write a value larger than the buffer
		9 	Application error, from using a Result

Parameters:
	_this select 0 - [String, nil] If String, this is the error message from the extension
	_this select 1 - [Scalar] The error code from arma-rs

Returns:
	A human readable reason for the error

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _errorReason = _this select 0;
private _errorCode = _this select 1;

switch (_errorCode) do
{
	// Handle the easy ones
	case 1: { "Function not found" };
	case 4: { "Function attempted to return too much data to Arma" };
	case 9: { format["Function returned error: %1", _errorReason] };

	// And now for 2x and 3x
	default
	{
		if (_errorCode >= 20 && { _errorCode <= 29}) exitWith
		{
			private _argumentCount = _errorCode - 20;
			format[
				"Function was given an unexpected amount of arguments. Given: %1",
				_argumentCount
			]
		};

		if (_errorCode >= 30 && { _errorCode <= 39}) exitWith
		{
			private _argumentPosition = _errorCode - 30;
			format[
				"Function argument at position %1 does not match the expected data type",
				_argumentPosition
			]
		};

		format["Function returned an unexpected error code: %1", _errorCode]
	};
}
