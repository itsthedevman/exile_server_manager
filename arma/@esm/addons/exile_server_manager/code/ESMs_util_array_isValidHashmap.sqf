/**
 *
 * Function:
 *      ESMs_util_array_isValidHashmap
 *
 * Description:
 *      Checks to see if an array can be converted to a hashmap
 *
 * Arguments:
 *      _this  	-> Any value to check
 *
 * Examples:
 *      [["key"], ["value"]] call ESMs_util_array_isValidHashmap; // true
 *      [["key", "value"]] call ESMs_util_array_isValidHashmap; // false
 *		"key" call ESMs_util_array_isValidHashmap // false
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

_this isEqualType [] &&
	count(_this) == 2 &&
	count(_this select 0) >= count(_this select 1)
