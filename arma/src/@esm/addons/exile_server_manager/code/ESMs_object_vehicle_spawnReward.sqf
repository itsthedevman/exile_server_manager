/* ----------------------------------------------------------------------------
Function:
	ESMs_object_vehicle_spawnReward

Description:
	Delivers a single reward vehicle to a player, either spawned near them or placed directly into a territory's virtual
	garage. Nothing escapes: every rejection is thrown as a failure code and caught here, so the caller can deliver the
	rest of the package and report per-vehicle reasons back to the bot.

Parameters:
	_playerObject	- The player receiving the vehicle. [Object]
	_playerUID		- The player's steam UID. [String]
	_vehicle		- The vehicle to deliver. [HashMap]
						class_name		- The vehicle's class name. [String]
						spawn_location	- "nearby" or "virtual_garage". [String]
						territory_database_id	- Territory database ID, required for "virtual_garage". The extension
							decodes it out of the entry's territory_id. [Scalar, nil]
						pin_code		- A four character pin. Generated when omitted. [String, nil]

Returns:
	[_delivered, _reason, _displayName, _pinCode] [Array]
		_delivered		- Whether the vehicle reached the player. [Boolean]
		_reason			- Failure code when _delivered is false, otherwise "". [String]
		_displayName	- The vehicle's readable name, falling back to its class name. [String]
		_pinCode		- The pin the vehicle was locked with, "" when undelivered. [String]

	Failure codes: invalid_class, unsupported_location, no_safe_position, territory_not_found, no_garage, garage_full

Examples:
	(begin example)

	[
		_playerObject,
		getPlayerUID _playerObject,
		createHashMapFromArray [["class_name", "Exile_Car_Hatchback_Rusty1"], ["spawn_location", "nearby"]]
	]
	call ESMs_object_vehicle_spawnReward;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _playerObject = _this select 0;
private _playerUID = _this select 1;
private _vehicle = _this select 2;

private _className = get!(_vehicle, "class_name", "");
private _spawnLocation = get!(_vehicle, "spawn_location", "nearby");
private _territoryID = get!(_vehicle, "territory_database_id", -1);
private _pinCode = get!(_vehicle, "pin_code", "");

// Declared out here so the catch can still name the vehicle in the failure it hands back
private _displayName = getText(configFile >> "CfgVehicles" >> _className >> "displayName");
if (empty?(_displayName)) then { _displayName = _className; };

private _result = [];

try
{
	if (empty?(_className) || { !(isClass(configFile >> "CfgVehicles" >> _className)) }) then
	{
		throw "invalid_class";
	};

	// "player_decides" lands here on purpose. It needs a choice the bot cannot ask for, so the website owns it.
	if !(_spawnLocation in ["nearby", "virtual_garage"]) then
	{
		throw "unsupported_location";
	};

	// Exile only ever compares this against a four character string. Generating one keeps the vehicle locked to
	// something the player is told, rather than leaving it on a shared default every other reward would also carry.
	if !((count _pinCode) isEqualTo 4) then
	{
		_pinCode = "";
		for "_i" from 1 to 4 do { _pinCode = _pinCode + str(floor(random 10)); };
	};

	private _isShip = _className isKindOf "Ship";
	private _storingInGarage = _spawnLocation isEqualTo "virtual_garage";

	private _flagObject = objNull;
	private _storedVehicles = [];
	private _spawnPosition = [];
	private _usePositionATL = true;

	if (_storingInGarage) then
	{
		_flagObject = _territoryID call ESMs_system_territory_get;
		if (isNull _flagObject) then { throw "territory_not_found"; };

		private _level = _flagObject getVariable ["ExileTerritoryLevel", 1];
		private _maxVehicles = (getArray(missionConfigFile >> "CfgVirtualGarage" >> "numberOfVehicles"))
			select ((_level - 1) max 0);

		if (_maxVehicles isEqualTo -1) then { throw "no_garage"; };

		// Counted the way Exile counts it. Its own cleanup soft-deletes stored vehicles without clearing territory_id,
		// so this list is the only number that agrees with what the garage will actually accept.
		_storedVehicles = _flagObject getVariable ["ExileTerritoryStoredVehicles", []];
		if ((count _storedVehicles) >= _maxVehicles) then { throw "garage_full"; };

		// A stored vehicle is still a row in the vehicle table, so it has to exist as an object long enough to be
		// inserted. Anywhere around the flag will do since it is deleted again a few lines later.
		_spawnPosition = (getPosATL _flagObject) findEmptyPosition [5, 100, _className];
		if (empty?(_spawnPosition)) then { _spawnPosition = getPosATL _flagObject; };
	}
	else
	{
		_usePositionATL = !_isShip;

		_spawnPosition = if (_isShip) then
		{
			[getPosATL _playerObject, 100, 20] call ExileClient_util_world_findWaterPosition
		}
		else
		{
			(getPos _playerObject) findEmptyPosition [10, 250, _className]
		};

		// Arma gives up rather than overlapping something. Same limit the vehicle trader lives with.
		if (empty?(_spawnPosition)) then { throw "no_safe_position"; };
	};

	private _vehicleObject = [_className, _spawnPosition, random 360, _usePositionATL, _pinCode]
		call ExileServer_object_vehicle_createPersistentVehicle;

	_vehicleObject setVariable ["ExileOwnerUID", _playerUID];
	_vehicleObject setVariable ["ExileIsLocked", 0];
	_vehicleObject lock 0;

	_vehicleObject call ExileServer_object_vehicle_database_insert;
	_vehicleObject call ExileServer_object_vehicle_database_update;

	// Storing hands the vehicle over to the flag and takes the object back out of the world
	if (_storingInGarage) then
	{
		_storedVehicles pushBack [_className, _displayName];
		_flagObject setVariable ["ExileTerritoryStoredVehicles", _storedVehicles, true];

		format[
			"storeVehicle:%1:%2:%3",
			_flagObject getVariable ["ExileDatabaseID", -1],
			_displayName,
			_vehicleObject getVariable ["ExileDatabaseID", -1]
		]
		call ExileServer_system_database_query_fireAndForget;

		_vehicleObject call ExileServer_system_vehicleSaveQueue_removeVehicle;
		_vehicleObject call ExileServer_system_simulationMonitor_removeVehicle;
		deleteVehicle _vehicleObject;
	};

	_result = [true, "", _displayName, _pinCode];
}
catch
{
	_result = [false, _exception, _displayName, ""];
};

_result
