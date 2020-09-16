MODULE: 
    xm8_notification_flag_steal_started
PURPOSE: 
    Add XM8 notification support for when a player starts to steal a flag
ADDS:
    Network Message for flagStealStartedRequest
OVERWRITES:
    ExileClient_action_stealFlag_duration.sqf
INSTRUCTIONS:
    - Copy the above files into your mission file and create overwrites for them (This gives you freedom to put them wherever)
        - If you already have existing overwrites for these files, make sure to merge them correctly
    - Copy the contents of CfgNetworkMessages.cpp into class CfgNetworkMessages in your mission config.cpp file (Or wherever you have it).
        - If you do not have class CfgNetworkMessages, create said class in your mission config.cpp file. 
            - If you do not know how to do this, plenty of other scripts on the Exile forums can show you how to do this.
    - Ensure you have exile_server_xm8.pbo and exile_server_flag_steal_started.pbo loaded on the server
    - Profit. There is no question about it.