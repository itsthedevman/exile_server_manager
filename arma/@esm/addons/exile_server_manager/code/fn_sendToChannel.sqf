/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Sends a message to a discord channel (Requires the discord channel ID)
*/

["discord_message_channel", [["channelID", _this select 0], ["message", _this select 1]]] call ESM_fnc_callExtension