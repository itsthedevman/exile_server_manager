/* ----------------------------------------------------------------------------
Function:
	ESMs_system_territory_incrementPaymentCounter

Description:
	Increments ESM's payment counter on the provided territory by one

Parameters:
	_this - [Nothing]

Returns:
	Nothing

Examples:
	(begin example)

		_territory call ESMs_system_territory_incrementPaymentCounter;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _paymentCounter = (_this getVariable ["ESM_PaymentCounter", 0]) + 1;

[
	"set_territory_payment_counter",
	[_this getVariable ["ExileDatabaseID", -1]],
	_paymentCounter
]
call ESMs_system_extension_call;

_this setVariable ["ESM_PaymentCounter", _paymentCounter];

nil
