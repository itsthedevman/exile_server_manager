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
 *      [["key_1", "value_1"], ["key_2", "value_2"]] call ESMs_util_hashmap_fromArray;
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

private _processor = {
	private _output = _this select 0;
	private _input = _this select 1;

	if !(_input call ESMs_util_array_isValidHashmap) exitWith {};

	{
		private _key = _x select 0;
		private _value = _x select 1;

		if (!(isNil "_value") && _value call ESMs_util_array_isValidHashmap) then
		{
			private _container = createHashMap;
			[_container, _value] call _processor;

			_value = _container;
		};

		_output set [
			if (isNil "_key") then { nil } else { _key },
			if (isNil "_value") then { nil } else { _value }
		];
	}
	forEach _input;
};

private _result = createHashMap;
[_result, _this] call _processor;

_result
