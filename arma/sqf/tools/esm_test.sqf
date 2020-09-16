[] spawn
{
	_flag = ({ if ((_x getVariable ["ExileDatabaseID", -1]) isEqualTo 1) exitWith { _x }} forEach (allMissionObjects "Exile_Construction_Flag_Static"));

	_flag call ExileServer_system_xm8_sendBaseRaid;
	_flag call ExileServer_system_xm8_sendChargePlantStated;
	_flag call ExileServer_system_xm8_sendFlagRestored;
	_flag call ExileServer_system_xm8_sendFlagStealStarted;
	_flag call ExileServer_system_xm8_sendFlagStolen;
	_flag call ExileServer_system_xm8_sendGrindingStarted;
	_flag call ExileServer_system_xm8_sendHackingStarted;
	["76561198037177305", "MX 6.5mm", "1000"] call ExileServer_system_xm8_sendItemSold;
	_flag call ExileServer_system_xm8_sendProtectionMoneyDue;
	_flag call ExileServer_system_xm8_sendProtectionMoneyPaid;
	[["76561198037177305"], "Hello", "World"] call ExileServer_system_xm8_sendCustom;

	["Test", "info"] call ESM_fnc_logToDLL;
	["info", "message", ["Hello World"]] call ESM_fnc_logToDiscord;
	["success","embed", ["Title", "Description", [["Field 1 Name", "Field 1 Value", false], ["Field 2 Name", "Field 2 Value", true], ["Field 3 Name", "Field 3 Value", true]]]] call ESM_fnc_logToDiscord;
	["426909048101797890", "Hello World"] call ESM_fnc_sendToChannel;
	["426909048101797890", ["Title", "Description", [["Field 1 Name", "Field 1 Value", false], ["Field 2 Name", "Field 2 Value", true], ["Field 3 Name", "Field 3 Value", true]], "BLUE"]] call ESM_fnc_sendToChannel;
	["426909048101797890", ["Title", "Description", [["Field 1 Name", "Field 1 Value", false], ["Field 2 Name", "Field 2 Value", true], ["Field 3 Name", "Field 3 Value", true]], "RED"]] call ESM_fnc_sendToChannel;
	["426909048101797890", ["Title", "Description", [["Field 1 Name", "Field 1 Value", false], ["Field 2 Name", "Field 2 Value", true], ["Field 3 Name", "Field 3 Value", true]], "BLACK"]] call ESM_fnc_sendToChannel;
	["426909048101797890", ["Title", "Description", [["Field 1 Name", "Field 1 Value", false], ["Field 2 Name", "Field 2 Value", true], ["Field 3 Name", "Field 3 Value", true]], "#1e354D"]] call ESM_fnc_sendToChannel;

	// These are purposely broken
	["426909048101797890", ["Title", "Description"]] call ESM_fnc_sendToChannel;
	["624387002443497489", "I should not see this"] call ESM_fnc_sendToChannel;
};
