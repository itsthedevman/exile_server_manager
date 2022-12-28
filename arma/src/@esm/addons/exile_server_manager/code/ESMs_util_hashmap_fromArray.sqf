/* ----------------------------------------------------------------------------
Function: ESMs_util_hashmap_fromArray

Description:
	Creates a hashmap from an array, similar to the command createHashMapFromArray, however this also recursively converts any hashmap like arrays it finds

Parameters:
	_this - The source array containing the keys and values for the hashmap [Array]

Returns:


Examples:
	(begin example)

	// Creates a hashmap representation of { "key_1": "value_1", "key_2": { "key_3": "value_3" } }
	[["key_1", "value_1"], ["key_2", [["key_3", "value_3"]]]] call ESMs_util_hashmap_fromArray;

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
			if (_this call ESMs_util_array_isValidHashmap) then
			{
				private _hashmap = createHashMap;

				{
					private _key = _x select 0;
					private _value = _x select 1;

					_hashmap set [
						_key,
						if (nil?(_value)) then { nil } else { _value call _processor }
					];
				}
				forEach _this;

				_hashmap
			}
			else
			{
				[_this, { _this call _processor }] call ESMs_util_array_map
			}
		};

		default { _this };
	}
};

private _result = _this call _processor;
if (type?(_result, HASH)) exitWith { _result };

nil
