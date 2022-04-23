/**
 *
 * Function:
 *      ESMs_object_embed_addField
 *
 * Description:
 *      Adds a field to an embed
 *
 * Arguments:
 *      _embed		-	The embed to add the field to
 *		_name		-	The name of the field
 *		_value		-	The value of the field
 *		_inline		-	Is this field inline? (Optional, defaults to false)
 *
 * Examples:
 *      [_embed, "Name", "Value", true] call ESMs_object_embed_addField;
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

private _embed = _this select 0;
private _name = _this select 1;
private _value = _this select 2;
private _inline = _this param [3, false];

private _field = createHashMapFromArray [["name", str(_name)], ["value", str(_value)], ["inline", _inline isEqualTo true]];
private _fields = _embed getOrDefault ["fields", []];

_fields pushBack _field;
_embed set ["fields", _fields];

nil
