/* ----------------------------------------------------------------------------
Function: ESMs_object_embed_addField

Description:
	Adds a field to an embed

Parameters:
	_embed		-	The embed to add the field to [String]
	_name		-	The name of the field [String]
	_value		-	The value of the field [String]
	_inline		-	Is this field inline? [true/false] (Optional, defaults to false)

Returns:
	Nothing

Examples:
	(begin example)

	[_embed, "Name", "Value", true] call ESMs_object_embed_addField;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

params [
	"_embed",
	["_name", [""]],
	["_value", [""]],
	["_inline", [], false]
];

private _fields = _embed getOrDefault ["fields", []];
_fields pushBack (["name", "value", "inline"] createHashMapFromArray [_name, _value, _inline isEqualTo true]);

_embed set ["fields", _fields];

nil
