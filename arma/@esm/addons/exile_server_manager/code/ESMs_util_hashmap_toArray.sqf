/* ----------------------------------------------------------------------------
Function: ESMs_util_hashmap_toArray

Description:
	Similarly to `toArray`, this function converts the provided hashmap to an array pairs ([[keys...], [values...]]), but recursively

Parameters:
	_this 	- The hashmap to convert

Returns:


Examples:
	(begin example)

	private _hashmap = createHashMap;
	_hashmap set ["key_1", "value_1"];

	private _subHash = createHashMap;
	_subHash set ["sub_key_1", "sub_value_1"];
	_hashmap set ["key_2", _subHash];

	_hashmap call ESMs_util_hashmap_toArray; // [["key_1", "key_2"], ["value_1", [["sub_key_1"], ["sub_value_1"]]]]

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
			// Bet you didn't know that Arma can scope like this
			[_this, { _this call _processor }] call ESMs_util_array_map;
		};

		case "HASHMAP":
		{
			private _result = [];
			{
				if (isNil "_x") then { continue; };

				_result pushBack [
					_x call _processor,

					// Arma has the worst implementation of `nil` I have ever seen
					// This is such a silly thing to have to do
					if (isNil "_y") then { nil } else { _y call _processor }
				];
			}
			forEach _this;

			_result
		};

		default
		{
			_this
		};
	};
};

_this call _processor
