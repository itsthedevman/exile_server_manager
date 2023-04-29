/* ----------------------------------------------------------------------------
Function: ESMs_util_embed_create

Description:
	Creates a hashmap representation of an embed.

Parameters:
	_this - An hashmap in array form containing valid embed attribute and the value to assign.
			Omitting an attribute will omit it from the final embed. Except for color, which is picked at random
			Valid attributes (all optional):
				title [String]
				description [String]
				color [String]
				fields [Array<[name, value, inline?]>]
			Valid colors:
				red, blue, green, yellow, orange, purple, pink, white

Returns:
	A validated hashmap containing the provided data.

Examples:
	(begin example)

	[
		["title", "This is the title"],
		["description", "This is a description"],
		["color", "yellow"],
		["fields", [ ["Field Name", "Field Value", false], ["Name field", "Value field", true] ]]
	]
	call ESMs_util_embed_create;

	// Embeds can also be created and modified using the helpers
	private _embed = [] call ESMs_util_embed_create;
	[_embed, "This is the title"] call ESMs_util_embed_setTitle;
	[_embed, "This is a description"] call ESMs_util_embed_setDescription;
	[_embed, "yellow"] call ESMs_util_embed_setColor;
	[_embed, "Field Name", "Field Value"] call ESMs_util_embed_addField;
	[_embed, "Name field", "Value field", true] call ESMs_util_embed_addField;
	_embed

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _embedData = _this;
private _embed = createHashMap;

if (nil?(_embedData) || { empty?(_embedData) }) exitWith { _embed };

if (type?(_embedData, ARRAY)) then
{
	_embedData = createHashmapFromArray _embedData;
};

if !(type?(_embedData, HASH)) exitWith { _embed };

if ("title" in _embedData) then
{
	[_embed, get!(_embedData, "title")] call ESMs_util_embed_setTitle;
};

if ("description" in _embedData) then
{
	[_embed, get!(_embedData, "description")] call ESMs_util_embed_setDescription;
};

if ("color" in _embedData) then
{
	[_embed, get!(_embedData, "color")] call ESMs_util_embed_setColor;
};

if ("fields" in _embedData) then
{
	{
		[
			_embed,
			_x select 0, 		// Name
			_x select 1, 		// Value
			_x param [2, nil] 	// Is the field inlined? Defaulting to nil so it uses addField's default (of false)
		]
		call ESMs_util_embed_addField;
	}
	forEach (get!(_embedData, "fields", []));
};

_embed
