/* ----------------------------------------------------------------------------
Function:
	ExileServer_system_xm8_sendProtectionMoneyPaid

Description:
	Notify players of the territory that their base protection money has been paid

Parameters:
	_this - [Object] The territory flag

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

[
	"protection-money-paid",
	_this getVariable ["ExileTerritoryBuildRights", []],
	[
		[
			"territory_id",
			_this getVariable ["ExileDatabaseID", -1]
		],
		[
			"territory_name",
			_this getVariable ["ExileTerritoryName", ""]
		]
	]
]
call ExileServer_system_xm8_send;

nil
