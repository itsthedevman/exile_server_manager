/**
 *
 * Function:
 *      ESMs_system_network_discord_log
 *
 * Description:
 *      Sends a message or embed to configured channel on your Discord server
 *
 * Arguments:
 *      _this	- The message to log. This can either be a message (as a String) or an embed (as a HashMap)
 *
 * Examples:
 *      ["This will log"] call ESMs_system_network_discord_log;
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

[ESM_LoggingChannelID, _this] call ESMs_system_network_discord_send_to;
