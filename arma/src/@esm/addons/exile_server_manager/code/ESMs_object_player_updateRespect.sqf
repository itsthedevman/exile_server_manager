/* ----------------------------------------------------------------------------
Function:
	ESMs_object_player_updateRespect

Description:
	Updates a player's respect over the network

Parameters:
	_this select 0 - [Object] The player object
	_this select 1 - [Scalar] The player's respect score

Returns:
	Nothing

Examples:
	(begin example)

		// Sets the player's respect to 100
		[_playerObject, 100] call ESMs_object_player_updateRespect;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-current_year!() Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

[
	_this select 1,
	{ ExileClientPlayerScore = _this; }
] remoteExecCall ["call", owner (_this select 0)];
