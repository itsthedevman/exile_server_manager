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

	debug!("Binding %1 (%2) to %3", _value, typeName(_value), _variableName);
	missionNameSpace setVariable [_variableName, _value];
}
forEach _variablesHash;

// Cache which extDB extension is being used. Makes calling extDB easier.
ESM_DatabaseExtension = format["extDB%1", ESM_ExtDBVersion];
ESM_Initialized = true;

// Acknowledge the message
[_id] call ESMs_system_message_respond_to;

info!("%1 (%2) - @esm version %3:%4 loaded - %5 detected", ESM_ServerID, ESM_CommunityID, ESM_Version, ESM_BuildNumber, ESM_DatabaseExtension);

true
