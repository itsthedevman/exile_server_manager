/**
 * ESM_system_extension_call
 * 	Calls the extension function, passing in any arguments
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 WolfkillArcadia
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 */

// If the argument is a string, we're trying to directly call a function with no arguments
if (_this isEqualType "") exitWith {
	["call", format["Calling extension with: %1", _this], "debug"] call ESMs_util_log;

	private _result = ("esm" callExtension _this) call ESMs_system_extension_processResult;
	["call", format["Extension returned: %1", _result], "debug"] call ESMs_util_log;

	_result
};

// The argument is an array
private _function = _this select 0;
private _arguments = _this select [1, count(_this) - 1];
private _sanitizedPackage = [];

// Cache a sanitizer function that escapes any JSON unsafe strings
private _sanitizer = {
	private _package = _this select 0;
	private _item = _this select 1;

	switch (typeName(_item)) do
	{
		case "ARRAY":
		{
			private _tempPackage = [];

			{
				[_tempPackage, _x] call _sanitizer;
			}
			forEach _item;

			_package pushBack _tempPackage;
		};

		case "STRING":
		{
			_package pushBack (_item call ExileClient_util_string_escapeJson);
		};

		default
		{
			_package pushBack _item;
		};
	};
};

// Using the saniziter, sanitize the package
{
	[_sanitizedPackage, _x] call _sanitizer;
}
forEach _arguments;

["call", format["Calling extension with: %1", _this], "debug"] call ESMs_util_log;

// Call the extension and return the result
// Calls to callExtension without arguments returns a string.
// Calls to callExtension with arguments returns an array.
// I forgot how _inconsistent_ Arma is.
private _result = "esm" callExtension [_function, _sanitizedPackage];

["call", format["Extension returned: %1", _result], "debug"] call ESMs_util_log;

if (_result isEqualType "") then {
	_result = parseSimpleArray(_result);
};

// If there is an issue, Arma will barf an error code here.
// Possible error codes:
//     101: SYNTAX_ERROR_WRONG_PARAMS_SIZE
//     102: SYNTAX_ERROR_WRONG_PARAMS_TYPE
//     201: PARAMS_ERROR_TOO_MANY_ARGS
//     301: EXECUTION_WARNING_TAKES_TOO_LONG
if ((_result select 2) > 0) exitWith {
	["call", format["ERROR - Arma barfed. Error code: %1", _result select 2]] call ESMs_util_log;
};

(_result select 0) call ESMs_system_extension_processResult
