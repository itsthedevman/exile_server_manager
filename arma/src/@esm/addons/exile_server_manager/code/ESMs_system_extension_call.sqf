/* ----------------------------------------------------------------------------
Function: ESMs_system_extension_call

Description:
	Calls ESM's extension with the provided function and data.

Parameters:
	_this  -  If _this is a string, it will be treated as the name of the endpoint.
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

if (type?(_this, STRING)) then
{
	_function = _this;
}
else
{
	// The argument should be an array
	_function = _this param [0, "", [""]];
	_arguments = _this select [1, count(_this) - 1];

	if (!type?(_arguments, ARRAY)) exitWith
	{
		error!("Invalid arguments provided for extension call to ""%1""", _function);
		false
	};
};

// Used to sanitize the arguments before sending them to the extension. Mainly to make the data JSON compatible as best I can
private _sanitizer = {
	// trace!("[%1] Sanitizing %2: %3", _id, typeName(_this), _this);

	switch (typeName(_this)) do
	{
		case "STRING";
		case "BOOL":
		{
			_this
		};

		case "ARRAY":
		{
			[_this, _sanitizer] call ESMs_util_array_map
		};

		case "SCALAR":
		{
			// Because arma
			str(_this)
		};

		case "HASHMAP":
		{
			[_this call ESMs_util_hashmap_toArray, _sanitizer] call ESMs_util_array_map
		};

		case "OBJECT";
		case "SCRIPT":
		{
			nil
		};

		default
		{
			error!("[%1] Unsupported type provided in arguments. Type: %3 | Value: %2", _id, _this, typeName _this);
			nil
		};
	};
};

// Using the sanitizer, sanitize the provided arguments
private _sanitizedArguments = [_arguments, _sanitizer] call ESMs_util_array_map;
// debug!("[%1] Calling endpoint ""%2"" with: %3", _id, _function, _sanitizedArguments);

// Call the extension and process the result
private _result = "esm" callExtension [_function, _sanitizedArguments];
// debug!("[%1] Endpoint ""%2"" replied with %3: %4", _id, _function, typeName _result, _result);

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
	error!("[%1] Extension barfed. Error code: %2", _id, _result select 1);
	false
};

// If there is an issue, Arma will return an error code.
//     101: SYNTAX_ERROR_WRONG_PARAMS_SIZE
//     102: SYNTAX_ERROR_WRONG_PARAMS_TYPE
//     201: PARAMS_ERROR_TOO_MANY_ARGS
//     301: EXECUTION_WARNING_TAKES_TOO_LONG
if ((_result select 2) > 0) exitWith
{
	error!("[%1] Arma barfed. Error code: %2", _id, _result select 2);
	false
};

// The result is worthless, don't try to process it
if ((_result select 0) isEqualTo "null") exitWith { nil };

// There was a returned value
(_result select 0) call ESMs_system_extension_processResult
