/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		XM8 Notification to the owner of the item being purchased through MarXet
*/
_recipient = _this select 0;
_itemSold = _this select 1;
_amount = _this select 2;

["marxet-item-sold", [_recipient], format['{ "item": "%1", "amount": "%2" }', _itemSold, _amount]] call ExileServer_system_xm8_send;