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
	© 2018-current_year!() Bryan "WolfkillArcadia"

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
private _sanitizedArguments = [
	_arguments,
	{
		private _result = _this call _sanitizer;

		// As of arma-rs 1.10, Array and Hashmap types are supported.
		// However, my own parser handles more complex scenarios when the data is a String
		if (type?(_result, ARRAY)) then
		{
			str(_result)
		}
		else
		{
			_result
		}
	}
]
call ESMs_util_array_map;

// debug!("[%1] Calling endpoint ""%2"" with: %3", _id, _function, _sanitizedArguments);

// Call the extension and process the result
private _result = "esm" callExtension [_function, _sanitizedArguments];
// debug!("[%1] Endpoint ""%2"" replied with %3: %4", _id, _function, typeName _result, _result);

// If there is an issue, Arma-rs will return an error code.
if ((_result select 1) > 0) exitWith
{
	private _reason = (_result select [0, 2]) call ESMs_util_extension_formatError;
	error!("[%1] Extension call to function ""%2"" barfed. %3", _id, _function, _reason);

	nil
};

// If there is an issue, Arma will return an error code.
if ((_result select 2) > 0) exitWith
{
	private _reason = (_result select 2) call ESMs_util_extension_formatArmaError;
	error!("[%1] Extension call to function ""%2"" caused Arma to barf. %3", _id, _function, _reason);

	nil
};

// The result is worthless, don't try to process it
if ((_result select 0) isEqualTo "null") exitWith { nil };

// There was a returned value
(_result select 0) call ESMs_system_extension_processResult
