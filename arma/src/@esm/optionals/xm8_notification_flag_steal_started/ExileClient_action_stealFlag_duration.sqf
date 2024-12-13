/* ----------------------------------------------------------------------------
Function:
	ExileClient_action_stealFlag_duration

Description:
	Original Exile code with an addition that triggers a flag-steal-started XM8 notification

Parameters:
	_this - [Object] The flag object

Returns:
	Scalar - How long it will take to steal the flag

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

private["_flagObject", "_level", "_duration"];

_flagObject = _this;

["flagStealStartedRequest", [_flagObject]] call ExileClient_system_network_send;

_level = _flagObject getVariable ["ExileTerritoryLevel", 0];

_duration = (1 + _level * 1.5) * 60;
_duration
