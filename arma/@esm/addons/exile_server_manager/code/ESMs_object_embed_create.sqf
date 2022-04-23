/**
 *
 * Function:
 *      ESMs_object_embed_create
 *
 * Description:
 *      Creates a hashmap representation of an embed
 *
 * Arguments:
 *      _this 	-> An hashmap in array form containing valid embed attribute and the value to assign
 *						Valid attributes: title, description, color, fields
 *
 * Examples:
 *      [["title", "This is the title"], ["description", "This is a description"]] call ESMs_object_embed_create;
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

private _embedData = _this;
if (isNil "_embedData") exitWith {};

if (_embedData isEqualType ARRAY_TYPE) then
{
	_embedData = _embedData call ESMs_util_hashmap_fromArray;
};

private _embed = createHashMap;
private _validKeys = ["title", "description", "color", "fields"];

{
	if (!(isNil "_x") && _x in _validKeys && (isNil "_y" || { _y isEqualType "" })) then
	{
		_embed set [_x, _y];
	};
}
forEach _embedData;

_embed
