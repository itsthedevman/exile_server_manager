/* ----------------------------------------------------------------------------
Function:
	ESMs_util_embed_setDescription

Description:
	Sets the embed's description to the provided value on

Parameters:
	_embed - [HashMap] The embed to set the description
	_description - [String] The description to set

Returns:
	Nothing

Examples:
	(begin example)

		// _embed: {}
		private _embed = [] call ESMs_util_embed_create;

		// _embed: { description: "This is a description" }
		[_embed, "This is a description"] call ESMs_util_embed_setDescription;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _embed = _this select 0;
private _value = _this select 1;

if (nil?(_value) || { empty?(_value) }) exitWith { nil };

_embed set ["description", _value];

nil
