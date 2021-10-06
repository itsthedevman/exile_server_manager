/**
 *
 * Function:
 *      ESMs_system_network_discord_send
 *
 * Description:
 *		Sends a message or embed to a Discord channel in your Discord server. The bot must have READ_MESSAGE and SEND_MESSAGE privileges to the channel
 *
 * Arguments:
 *      _channelNameOrID	- The channel Discord ID or it's name. The name must be exact!
 *		_messageOrEmbed		- A message (as a String) or an embed (as a Hashmap)
 *
 * Examples:
 *      ["discord_id", "Hello world!"] call ESMs_system_network_discord_send;
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

private _channelIDorName = _this select 0;
private _messageOrEmbed = _this select 1;

["send_to_channel", _channelIDorName, _messageOrEmbed] call ESMs_system_extension_call;
