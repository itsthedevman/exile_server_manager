/* ----------------------------------------------------------------------------
Function: ESMs_system_network_discord_send_to

Description:
	Sends a message or embed to a Discord channel in your Discord server. The bot must have READ_MESSAGE and SEND_MESSAGE privileges to the channel

Parameters:
	_channelNameOrID	- The channel Discord ID or it's name. The name must be exact and should not start with a '#'
	_messageOrEmbed		- A message (as a String) or an embed (as a Hashmap)

Returns:


Examples:
	(begin example)

	["discord_id", "Hello world!"] call ESMs_system_network_discord_send;

	private _embed = [["title", "My embed"]] call ESMs_util_embed_create;
	["my-awesome-channel", _embed] call ESMs_system_network_discord_send;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _channelIdOrName = _this select 0;
private _messageOrEmbed = _this select 1;

if (type?(_messageOrEmbed, HASH)) then
{
	_messageOrEmbed = str(_messageOrEmbed call ESMs_util_hashmap_toArray);
};

["send_to_channel", _channelIDorName, _messageOrEmbed] call ESMs_system_extension_call
