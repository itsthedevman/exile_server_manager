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
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

if (nil?(_this) || { empty?(_this) }) exitWith { createHashMap };

private _embedData = _this;

// Attempt to convert
if (type?(_embedData, ARRAY)) then
{
	_embedData = createHashmapFromArray _embedData;
};

// Ensure we're working with a HashMap
if (!type?(_embedData, HASH)) exitWith { createHashMap };

private _embed = createHashMap;

// Title
if ("title" in _embedData) then
{
	[_embed, get!(_embedData, "title")] call ESMs_util_embed_setTitle;
};

// Description
if ("description" in _embedData) then
{
	[_embed, get!(_embedData, "description")] call ESMs_util_embed_setDescription;
};

// Color
if ("color" in _embedData) then
{
	[_embed, get!(_embedData, "color")] call ESMs_util_embed_setColor;
};

// Fields
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
