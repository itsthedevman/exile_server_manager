/**
 *
 * Function:
 *      ESMs_system_process_postInit
 *
 * Description:
 *      Called after the extension has connected to the bot successfully. This function binds the required variables and their values.
 *
 * Arguments:
 *      _this	-	A hashmap representation of a Message
 *
 * Examples:
 *      Message call ESMs_system_process_postInit;
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

private _id = get!(_this, "id");
private _data = get!(_this, "data");

if (isNil "_id" || { isNil "_data" }) exitWith { nil };

// Bind the variables from CfgESM >> globalVariables, retrieving the values from _data
{
	private _variableName = _x;
	private _value = get!(_data, _variableName);
	if (isNil "_value") then { continue };

	info!("Binding %1 (%2) to %3", _value, typeName(_value), _variableName);
	missionNameSpace setVariable [_variableName, _value];
}
forEach (getArray (configFile >> "CfgESM" >> "globalVariables"));

// Cache which extDB extension is being used. Makes calling extDB easier.
ESM_DatabaseExtension = format["extDB%1", ESM_ExtDBVersion];
ESM_Initialized = true;

// Acknowledge the message
[_id] call ESMs_object_message_respond_to;

info!("Boot complete. Version %1:%2 has been loaded successfully. Detected database extension %3", ESM_Version, ESM_BuildNumber, ESM_DatabaseExtension);

true
