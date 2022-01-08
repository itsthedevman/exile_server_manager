/**
 *
 * Function:
 *      ESMs_util_hashmap_fromArray
 *
 * Description:
 *      Creates a hashmap from an array, similar to the command createHashMapFromArray, however this also recursively converts any hashmap like arrays it finds
 *
 * Arguments:
 *      _this 	- The source array containing the keys and values for the hashmap
 *
 * Examples:
 *		// Creates a hashmap with "key_1" containing the scalar 1 and "key_2" containing the string "value_2"
 *      [["key_1", "key_2"], [1, "value_2"]] call ESMs_util_hashmap_fromArray;
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

private _check = {
	if (isNil "_this") exitWith { false };
	if !(_this isEqualType []) exitWith { false };

	count(_this) == 2 && count(_this select 0) >= count(_this select 1)
};

private _processor = {
	if !(_this call _check) exitWith { _this };

	_this params [
		["_keys", [], [[]]],
		["_values", [], [[]]]
	];

	private _sanitizedValues = [];
	{
		private _key = _x;
		private _value = _values select _forEachIndex;

		if (isNil "_value") then
		{
			_sanitizedValues pushBack nil;
			continue;
		};

		_sanitizedValues pushBack (_value call _processor);
	}
	forEach _keys; // The keys are what matter here. We don't care if it doesn't have a value

	_keys createHashMapFromArray _sanitizedValues
};

_this call _processor
