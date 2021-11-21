/**
 *
 * Function:
 *      ESMs_system_extension_call
 *
 * Description:
 *		Calls ESM's extension with the provided function and data.
 *
 * Arguments:
 *      _this 		- 	If _this is a string, it will be treated as the name of the endpoint.
 *						If _this is an array, the first element will be treated as the name of the endpoint and any other elements as arguments
 *
 * Examples:
 *      "ext_function" call ESMs_system_extension_call;
 *
 *		["ext_function", "arg 1", true, 55] call ESMs_system_extension_call;
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

private _id = floor(random 100);

// If the argument is a string, we're trying to call a function with no arguments
if (_this isEqualType "") exitWith {
	["call", format["[%1] Calling extension endpoint ""%2""", _id, _this], "debug"] call ESMs_util_log;

	// Surprisingly, this actually just returns a string
	private _result = ("esm" callExtension _this) call ESMs_system_extension_processResult;

	["call", format["[%1] Extension returned: %2", _id, _result], "debug"] call ESMs_util_log;
	_result
};

// The argument is an array
private _function = _this param [0, "", [""]];
private _arguments = _this select [1, count(_this) - 1];
if !(_arguments isEqualType []) exitWith {};

// Cache a sanitizer function that escapes any JSON unsafe strings
private _sanitizer = {
	private _package = _this select 0;
	private _item = _this select 1;

	if (isNil "_item") exitWith { _package pushBack nil };

	switch (typeName(_item)) do
	{
		case "ARRAY":
		{
			private _sanitizedValue = [];

			{
				[
					_sanitizedValue,
					if (isNil "_x") then { nil } else { _x }
				] call _sanitizer;
			}
			forEach _item;

			_package pushBack _sanitizedValue;
		};

		case "STRING":
		{
			_package pushBack (_item call ExileClient_util_string_escapeJson);
		};

		case "SCALAR":
		{
			_package pushBack str(_item);
		};

		case "BOOL":
		{
			_package pushBack _item;
		};

		case "ANY":
		{
			_package pushBack nil;
		};

		case "HASHMAP":
		{
			private _arrayPairs = _item call ESMs_util_hashmap_toArray;

			private _keys = [];
			{
				[
					_keys,
					if (isNil "_x") then { nil } else { _x }
				]
				call _sanitizer;
			}
			forEach (_arrayPairs select 0);

			private _values = [];
			{
				[
					_values,
					if (isNil "_x") then { nil } else { _x }
				]
				call _sanitizer;
			}
			forEach (_arrayPairs select 1);

			_package pushBack [_keys, _values];
		};

		default
		{
			["call", format["Unsupported type provided in arguments. Type: %2 | Value: %1", _item, typeName _item], "error"] call ESMs_util_log;
		};
	};
};

// Using the sanitizer, sanitize the provided arguments
private _sanitizedArguments = [];
{
	[
		_sanitizedArguments,
		if (isNil "_x") then { nil } else { _x }
	] call _sanitizer;
}
forEach _arguments;

["call", format["[%1] Calling extension endpoint ""%2"" with %3", _id, _function, _sanitizedArguments], "debug"] call ESMs_util_log;

// Call the extension and process the result
// Calls to callExtension without arguments returns a string.
// Calls to callExtension with arguments returns an array. And sometimes a string...
// I forgot how _inconsistent_ Arma is.
private _result = "esm" callExtension [_function, _sanitizedArguments];

["call", format["[%1] Extension returned: %2", _id, _result], "debug"] call ESMs_util_log;

if (_result isEqualType "") then {
	_result = parseSimpleArray(_result);
};

// If there is an issue, Arma will barf an error code.
// Possible error codes:
//     101: SYNTAX_ERROR_WRONG_PARAMS_SIZE
//     102: SYNTAX_ERROR_WRONG_PARAMS_TYPE
//     201: PARAMS_ERROR_TOO_MANY_ARGS
//     301: EXECUTION_WARNING_TAKES_TOO_LONG
if ((_result select 2) > 0) exitWith {
	["call", format["Arma barfed. Error code: %1", _result select 2], "error"] call ESMs_util_log;
};

(_result select 0) call ESMs_system_extension_processResult
