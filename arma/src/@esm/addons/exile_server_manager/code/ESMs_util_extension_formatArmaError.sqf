/* ----------------------------------------------------------------------------
Function:
	ESMs_util_extension_formatArmaError

Description:
	Formats the error codes from Arma
	    101: SYNTAX_ERROR_WRONG_PARAMS_SIZE
	    102: SYNTAX_ERROR_WRONG_PARAMS_TYPE
	    201: PARAMS_ERROR_TOO_MANY_ARGS
	    301: EXECUTION_WARNING_TAKES_TOO_LONG

Parameters:
	_this - [Scalar] The error code

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

switch (_this) do
{
	case 101: { "SYNTAX ERROR: Wrong parameter size" };
	case 102: { "SYNTAX ERROR: Wrong parameter type" };
	case 201: { "PARAMS ERROR: Too many arguments" };
	case 301: { "EXECUTION ERROR: Timeout"};
}
