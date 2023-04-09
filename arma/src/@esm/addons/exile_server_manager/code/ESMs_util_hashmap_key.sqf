/* ----------------------------------------------------------------------------
Function: ESMs_util_hashmap_key

Description:
	Traverses the provided hashmap with the provided keys to see if the last key exists

Parameters:
	_hashMap 	- A hashmap to get the data from
	..._keys	- The key(s) to get from the hash

Returns:
	true/false if the key exists

Examples:
	(begin example)

	// { key_1: { key_2: false } }
    private _hashMap = [["key_1", [["key_2", false]]]] call ESMs_util_hashmap_fromArray;

	[_hashMap, "key_1"] call ESMs_util_hashmap_key; // true
	[_hashMap, "key_1", "key_2"] call ESMs_util_hashmap_key; // true
	[_hashMap, "key_1", "foo"] call ESMs_util_hashmap_key; // false
	[_hashMap, "key_n", "key_2"] call ESMs_util_hashmap_key; // false

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _result = _this call ESMs_util_hashmap_dig;
!nil?(_result)
