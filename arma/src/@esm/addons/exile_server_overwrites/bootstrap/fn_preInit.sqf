{
    if (isClass(configFile >> "CfgPatches" >> _x select 1)) then
    {
        missionNamespace setVariable [
            _x select 0,
            compileFinal preprocessFileLineNumbers format["%1\code\%2.sqf", _x select 1, _x select 0]
        ];

        diag_log format["[Exile Server Manager] Patched %1", _x select 0];
    };
}
forEach
[
    // XM8
	["ExileServer_system_xm8_send", "exile_server_xm8"],
    ["ExileServer_system_xm8_sendBaseRaid", "exile_server_xm8"],
	["ExileServer_system_xm8_sendFlagRestored", "exile_server_xm8"],
	["ExileServer_system_xm8_sendFlagStolen", "exile_server_xm8"],
	["ExileServer_system_xm8_sendProtectionMoneyDue", "exile_server_xm8"],
	["ExileServer_system_xm8_sendProtectionMoneyPaid", "exile_server_xm8"],

    // Custom XM8 Notifications
    ["ExileServer_system_xm8_sendGrindingStarted", "exile_server_xm8"],
    ["ExileServer_system_xm8_sendHackingStarted", "exile_server_xm8"],
    ["ExileServer_system_xm8_sendChargePlantStarted", "exile_server_xm8"],
    ["ExileServer_system_xm8_sendFlagStealStarted", "exile_server_xm8"],
    ["ExileServer_system_xm8_sendItemSold", "exile_server_xm8"],
    ["ExileServer_system_xm8_sendCustom", "exile_server_xm8"],

    // Charge Plant Started
    ["ExileServer_system_breaching_network_breachingPlaceRequest", "exile_server_charge_plant_started"],

    // Flag Steal Started
    ["ExileServer_system_territory_network_flagStealStartedRequest", "exile_server_flag_steal_started"],

    // Grinding
    ["ExileServer_object_lock_network_grindNotificationRequest", "exile_server_grinding"],

    // Hacking
    ["ExileServer_object_lock_network_startHackRequest", "exile_server_hacking"],

    // OPC!
    ["ExileServer_system_network_event_onPlayerConnected", "exile_server_player_connected"],

    // For testing purposes and only loads if esm_test.pbo exists and contains this file
    ["ExileClient_util_player_objectFromPlayerUID", "esm_test"]
];

call compile (preprocessFileLineNumbers "exile_server\bootstrap\fn_preInit.sqf");

true
