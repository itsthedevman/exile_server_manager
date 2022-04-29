/* ----------------------------------------------------------------------------
Function: ESMs_util_hashmap_fromArray

Description:
	Creates a hashmap from an array, similar to the command createHashMapFromArray, however this also recursively converts any hashmap like arrays it finds

Parameters:
	_this - The source array containing the keys and values for the hashmap [Array]

Returns:


Examples:
	(begin example)

	// Creates a hashmap with "key_1" containing the scalar 1 and "key_2" containing the string "value_2"
	[["key_1", "key_2"], ["value_1", "value_2"]] call ESMs_util_hashmap_fromArray;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _processor = {
	switch (typeName _this) do
	{
		case "ARRAY":
		{
			private _result = _this;
			private _sanitizedValues = [];

			if (_this call ESMs_util_array_isValidHashmap) then
			{
				_this params [
					["_keys", [], [[]]],
					["_values", [], [[]]]
				];

				private _valuesSize = count(_values);
				{
					private _key = _x;
					private _value = nil;

					// "zero divisor" is raised if the index is higher than the array size
					if (_forEachIndex < _valuesSize) then
					{
						_value = _values select _forEachIndex;
					};

					if (isNil "_value") then
					{
						// Because Arma does not support `_sanitizedValues pushBack nil` - Again, the worst implementation of nil ever
						_sanitizedValues set [_forEachIndex, nil];
						continue;
					};

					_sanitizedValues pushBack (_value call _processor);
				}
				forEach _keys; // The keys are what matter here. We don't care if it doesn't have a value

				_keys createHashMapFromArray _sanitizedValues
			}
			else
			{
				{
					_sanitizedValues pushBack (_x call _processor);
				}
				forEach _this;

				_sanitizedValues
			};
		};

		default { _this };
	};
};

private _result = _this call _processor;
if (_result isEqualType HASH_TYPE) exitWith { _result };

nil
