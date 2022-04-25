/* ----------------------------------------------------------------------------
Function: ESMs_system_extension_call

Description:
	Calls ESM's extension with the provided function and data.

Parameters:
	_this 	- 	If _this is a string, it will be treated as the name of the endpoint.
				If _this is an array, the first element will be treated as the name of the endpoint and any other elements as arguments

Returns:
	The result from the extension call

Examples:
	(begin example)

	"ext_function" call ESMs_system_extension_call;
	["ext_function", "arg 1", true, 55] call ESMs_system_extension_call;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */


private _id = floor(random 100);
private _function = "";
private _arguments = [];

if (_this isEqualType "") then
{
	_function = _this;
}
else
{
	// The argument should be an array
	_function = _this param [0, "", [""]];
	_arguments = _this select [1, count(_this) - 1];

	if !(_arguments isEqualType []) exitWith
	{
		["extension_call", format["Invalid arguments provided for extension call to ""%1""", _function]] call ESMs_util_log;
	};
};

// Cache a sanitizer function that escapes any JSON unsafe strings
private _sanitizer = {
	private _package = _this select 0;
	private _item = _this select 1;

	if (isNil "_item") exitWith { _package pushBack nil };

	switch (typeName(_item)) do
	{
		case "STRING";
		case "BOOL":
		{
			_package pushBack _item;
		};

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

		case "SCALAR":
		{
			_package pushBack str(_item);
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
			["extension_call", format["Unsupported type provided in arguments. Type: %2 | Value: %1", _item, typeName _item], "error"] call ESMs_util_log;
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

["extension_call", format["[%1] Calling extension endpoint ""%2"" with %3", _id, _function, _sanitizedArguments], "debug"] call ESMs_util_log;

// Call the extension and process the result
private _result = "esm" callExtension [_function, _sanitizedArguments];

["extension_call", format["[%1] Extension returned (%2): %3", _id, typeName _result, _result], "debug"] call ESMs_util_log;

// If there is an issue, Arma-rs will return an error code.
// Possible error codes:
// 		0 	Success
// 		1 	Command not found
// 		2x 	Invalid argument count, x is received count
// 		3x 	Invalid argument type, x is argument position
// 		4 	Attempted to write a value larger than the buffer
// 		9 	Application error, from using a Result
if ((_result select 1) > 0) exitWith
{
	["extension_call", format["Extension barfed. Error code: %1", _result select 1], "error"] call ESMs_util_log;
};

// If there is an issue, Arma will return an error code.
//     101: SYNTAX_ERROR_WRONG_PARAMS_SIZE
//     102: SYNTAX_ERROR_WRONG_PARAMS_TYPE
//     201: PARAMS_ERROR_TOO_MANY_ARGS
//     301: EXECUTION_WARNING_TAKES_TOO_LONG
if ((_result select 2) > 0) exitWith {
	["extension_call", format["Arma barfed. Error code: %1", _result select 2], "error"] call ESMs_util_log;
};

(_result select 0) call ESMs_system_extension_processResult
