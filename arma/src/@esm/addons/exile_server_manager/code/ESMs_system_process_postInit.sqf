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

if (nil?(_id) || { nil?(_data) }) exitWith { nil };

private _variablesHash = (getArray (configFile >> "CfgESM" >> "globalVariables")) call ESMs_util_hashmap_fromArray;

// Bind the variables from CfgESM >> globalVariables, retrieving the values from _data
{
	private _attributeName = _x;
	private _variableName = _y;

	private _value = get!(_data, _attributeName);
	if (nil?(_value)) then {
		error!("Failed to a value for %1", _attributeName);
		continue;
	};

	missionNameSpace setVariable [_variableName, _value];

	info!("%1 = %3; // %2", _variableName, typeName(_value), if (type?(_value, STRING)) then { format["'%1'", _value] } else { _value });
}
forEach _variablesHash;

// Cache which extDB extension is being used. Makes calling extDB easier.
ESM_DatabaseExtension = format["extDB%1", ESM_ExtDBVersion];
ESM_Initialized = true;

// Acknowledge the message
[_id] call ESMs_system_message_respond_to;

info!("Initialization completed");

true
