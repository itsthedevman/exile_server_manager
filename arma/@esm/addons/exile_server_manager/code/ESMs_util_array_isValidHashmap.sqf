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
 *      [["key", "value"]] call ESMs_util_array_isValidHashmap; // true
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

if !(_this isEqualType ARRAY_TYPE) exitWith {};

private _size = count(_this);
private _pairCount = { count(_x) isEqualTo 2 } count _this;

_pairCount isEqualTo _size
