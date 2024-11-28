/* ----------------------------------------------------------------------------
Function:
	ExileServer_system_xm8_sendGrindingStarted

Description:
	Notify players of the territory that someone is trying to hack into their base

Parameters:
	_this - [Object] The territory flag

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

[
	"hack-started",
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
