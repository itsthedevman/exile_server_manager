/* ----------------------------------------------------------------------------
Function:
	ExileServer_system_xm8_sendCustom

Description:
	Sends a custom notification

Parameters:
	_recipientUIDs 	- [Array<String>] An array of player UIDs
	_embedData 		- [HashMap<String, Any>] An embed to send to the UIDs

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _recipientUIDs = _this select 0;
private _embedData = _this select 1;

["custom", _recipientUIDs, _embedData] call ExileServer_system_xm8_send;

nil
