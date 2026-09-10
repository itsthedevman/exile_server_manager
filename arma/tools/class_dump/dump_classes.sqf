/* ----------------------------------------------------------------------------
Script:
	dump_classes.sqf

Description:
	Walks one config root and reports every public class in it as a flat row, for rebuilding
	core/config/arma_classes/*.yml against a server running the mods those files describe.

	Sent as a code string through ESMs_command_sqf rather than shipped in @esm, so it is not a named
	function and is never registered in fn_preInit.

	Categories come from BIS_fnc_itemType wherever it has an opinion, because the engine already
	knows what it would call a thing and the config alone does not: BI hangs machine guns, shotguns
	and marksman rifles off one shared base class. It says nothing about vehicles, which fall back to
	inheritance, and nothing useful about Exile's items, which all report UnknownMagazine because
	medicine, food and building material are a distinction Exile only makes by hand. The caller keeps
	the category it already had for any class it already knows, so this only has to be right about
	classes nobody has categorised before.

	Rows are flat on purpose. Grouping them by mod and category, and writing the YAML, is the calling
	Ruby script's job.

Parameters:
	_section - [String] The config root to walk. One of "CfgWeapons", "CfgMagazines", "CfgVehicles",
	           "CfgGlasses". Set by the caller prepending an assignment to this file's contents.

Returns:
	[String] A JSON array of [className, displayName, sourceMod, category] rows.

Author:
	Exile Server Manager
	www.esmbot.com
---------------------------------------------------------------------------- */

if (isNil "_section") exitWith { "[]" };

/*
	What BIS_fnc_itemType's second value maps onto, keyed by the first.

	Shotguns land in misc_weapons and glasses in clothing_headgear because that is where the existing
	files put them, and a regenerated file that reshuffles categories nobody asked to change is a
	diff nobody can read.
*/
private _byItemType = createHashMapFromArray [
	["Weapon", createHashMapFromArray [
		["AssaultRifle", "rifles"],
		["MachineGun", "machine_guns"],
		["SniperRifle", "sniper_rifles"],
		["SubmachineGun", "sub_machine_guns"],
		["Shotgun", "misc_weapons"],
		["Handgun", "handguns"],
		["RocketLauncher", "launchers"],
		["MissileLauncher", "launchers"],
		["Throw", "melee"]
	]],
	["Magazine", createHashMapFromArray [
		["Bullet", "magazines"],
		["Grenade", "magazines_grenades"],
		["Shell", "magazines_grenades"],
		["Rocket", "magazines_rockets"],
		["Missile", "magazines_rockets"]
	]],
	["Mine", createHashMapFromArray [
		["Mine", "magazines_explosives"],
		["MineBounding", "magazines_explosives"],
		["MineDirectional", "magazines_explosives"]
	]],
	["Equipment", createHashMapFromArray [
		["Backpack", "clothing_backpacks"],
		["Vest", "clothing_vests"],
		["Headgear", "clothing_headgear"],
		["Uniform", "clothing_uniforms"],
		["Glasses", "clothing_headgear"]
	]],
	["Item", createHashMapFromArray [
		["AccessorySights", "attachment_sights"],
		["AccessoryMuzzle", "attachments_muzzles"],
		["AccessoryPointer", "attachments_pointers"],
		["AccessoryBipod", "attachment_bipods"]
	]]
];

// Where a class lands when the engine names a family but not a member of it, so that a weapon the
// engine calls a Cannon is still filed as a weapon rather than dropped.
private _byFamily = createHashMapFromArray [
	["Weapon", "misc_weapons"],
	["Magazine", "magazines"],
	["Mine", "magazines_explosives"],
	["Equipment", "items"],
	["Item", "items"]
];

/*
	JSON escaping, on the two characters that can break the payload.

	splitString is not usable here: it drops empty tokens, so a name that opens or closes on the
	delimiter comes back wrong. Walking the character codes is slower and correct.
*/
private _escapeJson =
{
	private _output = [];

	{
		switch (_x) do
		{
			case 34: { _output append [92, 34] };
			case 92: { _output append [92, 92] };
			default { _output pushBack _x };
		};
	}
	forEach (toArray _this);

	toString _output;
};

/*
	CfgVehicles is the noisy one, and the one the engine classifier has nothing to say about. It
	holds every building, prop and agent in the game alongside the things a player can be given, so
	anything that matches no known base is dropped rather than swept into a catch-all.
*/
private _vehicleCategory =
{
	private _className = configName _this;

	switch (true) do
	{
		case (_className isKindOf "Bag_Base"): { "clothing_backpacks" };
		case (_className isKindOf "StaticWeapon"): { "vehicle_static" };
		case (_className isKindOf "Car"): { "vehicle_car" };
		case (_className isKindOf "Tank"): { "vehicle_tank" };
		case (_className isKindOf "Ship"): { "vehicle_boat" };
		case (_className isKindOf "Helicopter"): { "vehicle_helicopter" };
		case (_className isKindOf "Plane"): { "vehicle_plane" };
		default { "" };
	};
};

private _rows = [];

{
	private _config = _x;
	private _className = configName _config;

	// scope 2 is Arma's own word for "a player may be handed this", and a class with no inventory
	// picture is not something a player ever sees in one. Both filters together are what separate
	// real items from the base classes and placeholders sharing the config tree with them.
	if (getNumber (_config >> "scope") < 2) then { continue };
	if (getText (_config >> "picture") isEqualTo "" && _section isEqualTo "CfgWeapons") then { continue };

	private _displayName = getText (_config >> "displayName");
	if (_displayName isEqualTo "") then { continue };

	private _category = "";

	if (_section isEqualTo "CfgVehicles") then
	{
		_category = _config call _vehicleCategory;
	}
	else
	{
		private _itemType = [_className] call BIS_fnc_itemType;
		private _family = _itemType select 0;

		_category = (_byItemType getOrDefault [_family, createHashMap]) getOrDefault [
			_itemType select 1,
			_byFamily getOrDefault [_family, ""]
		];
	};

	if (_category isEqualTo "") then { continue };

	// Most display names are plain, so the escape only runs for the few that are not
	if (_displayName find """" > -1 || { _displayName find "\" > -1 }) then
	{
		_displayName = _displayName call _escapeJson;
	};

	_rows pushBack format [
		"[""%1"",""%2"",""%3"",""%4""]",
		_className,
		_displayName,
		configSourceMod _config,
		_category
	];
}
forEach ("true" configClasses (configFile >> _section));

"[" + (_rows joinString ",") + "]"
