/* ----------------------------------------------------------------------------
Function:
	ExileServer_system_xm8_send

Description:
	Enqueues an XM8 notification to be sent to the bot as soon as possible.
	Used internally by other XM8 functions:
		- ExileServer_system_xm8_sendBaseRaid
		- ExileServer_system_xm8_sendChargePlantStarted
		- ExileServer_system_xm8_sendCustom
		- ExileServer_system_xm8_sendFlagRestored
		- ExileServer_system_xm8_sendFlagStealStarted
		- ExileServer_system_xm8_sendFlagStolen
		- ExileServer_system_xm8_sendGrindingStarted
		- ExileServer_system_xm8_sendHackingStarted
		- ExileServer_system_xm8_sendItemSold
		- ExileServer_system_xm8_sendProtectionMoneyDue
		- ExileServer_system_xm8_sendProtectionMoneyPaid

Parameters:
	_notificationType	- [String]
	_recipientUIDs		- [Array<String>]
	_content			- [HashMap<String, Any>]
Returns:
	Nothing

Examples:
	(begin example)

		[
			"custom",
			["UID1", "UID2", "UID3"],
			[
				["title", "This is the title!"],
				["description", "This is the description"]
			]
		]
		call ExileServer_system_xm8_send;

	(end)

Author:
	Exile Mod
	www.exilemod.com
	© 2015-current_year!() Exile Mod Team

	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

Co-author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.
---------------------------------------------------------------------------- */

private _notificationType = _this select 0;
private _recipientUIDs = _this select 1;
private _content = _this select 2;

try
{
	if (!type?(_recipientUIDs, ARRAY)) then
	{
		throw "Invalid recipient array";
	};

	// Filter duplicate recipients
	_recipientUIDs = _recipientUIDs call ExileClient_util_array_unique;
	if (empty?(_recipientUIDs)) then
	{
		throw "No recipients";
	};

	[
		"add_xm8_notification",
		_notificationType,
		_recipientUIDS,
		_content
	]
	call ESMs_system_extension_call;
}
catch
{
	error!("Failed to send %1: %2", _notificationType, _exception);
};

nil
