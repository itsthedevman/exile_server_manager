/**
 *
 * Function:
 *      ESMs_util_hashmap_toArray
 *
 * Description:
 *      Converts the provided hashmap to an array but it will also convert child hashmaps as well
 *
 * Arguments:
 *      _this		- The hashmap to convert
 *
 * Examples:
 *      HashMap call ESMs_util_hashmap_toArray;
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

private _hash = _this;
private _processor = {
	private _input = _this;
	private _result = _input;

	if (_input isEqualType HASH_TYPE) then
	{
		// Arma has the worst implementation of `nil` I have ever seen
		// This is such a silly thing to have to do
		{
			_input set [
				if (isNil "_x") then { nil } else { _x call _processor },
				if (isNil "_y") then { nil } else { _y call _processor }
			];
		}
		forEach _input;

		_result = toArray _input;
	};

	_result
};

_hash call _processor
