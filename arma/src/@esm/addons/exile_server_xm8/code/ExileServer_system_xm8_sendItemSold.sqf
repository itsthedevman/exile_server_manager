/* ----------------------------------------------------------------------------
Function:
	ExileServer_system_xm8_sendItemSold

Description:
	Notifies a player that they sold an item on Exile's leading marketplace, MarXet

Parameters:
	_recipientUID	- [String] The player to notify
	_itemName		- [String] The name of the item sold
	_poptabs		- [String] The amount of poptabs the player was given

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _recipientUID = _this select 0;
private _itemName = _this select 1;
private _poptabs = _this select 2;

[
	"marxet-item-sold",
	[_recipientUID],
	[
		["item_name", _itemName],
		["poptabs_received", _poptabs]
	]
]
call ExileServer_system_xm8_send;

nil
