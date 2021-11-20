/**
 *
 * Function:
 *      ESMs_util_hashmap_get
 *
 * Description:
 *      Attempts to retrieve the key(s) from the hashmap. If a key is not found, nil will be returned.
 *		Similar to Ruby's hash&.dig(:key_1)&.dig(:key_2)&.dig(:key_n)
 *
 * Arguments:
 *      _hashMap 	- A hashmap to get the data from
 *		..._keys	- The key(s) to get from the hash
 *
 * Examples:
 *      [_hashMap, "key_1"] call ESMs_util_hashmap_get;
 *		[_hashMap, "key_1", "key_2"] call ESMs_util_hashmap_get;
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

private _hashMap = _this select 0;
private _keys = _this select [1, count(_this)];

// Used for checking types
private _hashType = createHashMap;
private _result = _hashMap;

{
	private _key = _x;

	// If this is nil, the key wasn't found or extra keys were provided
	if !(_result isEqualType _hashType) exitWith {};

	_result = _result getOrDefault [_key, nil];
}
forEach _keys;

_result
