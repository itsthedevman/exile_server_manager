/* ----------------------------------------------------------------------------
Function: ESMs_util_hashmap_dig

Description:
	Attempts to retrieve the key(s) from the hashmap. If a key is not found, nil will be returned.
	Functions like Ruby's Hash#dig method: {key_1: {key_2: {key_n: "foo"}}}.dig(:key_1, :key_2, :key_n) => "foo"

Parameters:
	_hashMap 	- A hashmap to get the data from
	..._keys	- The key(s) to get from the hash

Returns:
	The value that is stored in the keys or nil if not found/does not exist

Examples:
	(begin example)

	[_hashMap, "key_1"] call ESMs_util_hashmap_dig;
	[_hashMap, "key_1", "key_2"] call ESMs_util_hashmap_dig;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _hashMap = _this select 0;
private _total = count(_this);
private _keys = _this select [1, _total];
private _lastIndex = _total - 2;

private _result = {
	private _key = _x;
	if (isNil "_hashMap" || { !type?(_hashMap, HASH) }) exitWith { nil };

	_hashMap = get!(_hashMap, _key);
	if (_forEachIndex isEqualTo _lastIndex) exitWith
	{
		if (nil?(_hashMap)) then { nil } else { _hashMap }
	};

	nil
}
forEach _keys;

// If a variable is nil, arma WILL NOT let you reference it. Hence why `isNil` only accepts a string ;)
if (nil?(_result)) then { nil } else { _result }
