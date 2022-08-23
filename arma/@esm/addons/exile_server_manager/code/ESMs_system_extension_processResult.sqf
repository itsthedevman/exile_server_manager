/* ----------------------------------------------------------------------------
Function: ESMs_system_extension_processResult

Description:
	Processes the result from the callExtension and converts array strings to arrays

Parameters:
	_this - Can be an array string "[]" with content or really anything else

Returns:
	_this if not an array string
	Hashmap if _this is an array string

Examples:
	(begin example)

	"This will stay a string" call ESMs_system_extension_processResult;
	"[""This will be converted"",""to an array""]" call ESMs_system_extension_processResult;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _result = _this;

// The extension sends back a empty string after receiving a call
if (nil?(_result) || { type?(_result, STRING) }) exitWith { true };

if (type?(_result, STRING)) then
{
	// Only convert array strings. Ignore everything else. (91 == [) and (93 == ])
	private _chars = toArray _result;
	if ([_chars select 0, _chars select (count _chars - 1)] isEqualTo [91, 93]) then
	{
		_result = parseSimpleArray _result;
	};
};

if (_result call ESMs_util_array_isValidHashmap) then
{
	_result = _result call ESMs_util_hashmap_fromArray;

	// Rust will convert Empty into null. null does not trigger the default in "getOrDefault"
	// To get around this, just delete the key.
	{
		if !(_x in _result) then { continue; };

		private _value = _result get _x;
		if (nil?(_value)) then
		{
			_result deleteAt _x;
		};
	}
	forEach ["id", "data", "metadata"];
};

_result
