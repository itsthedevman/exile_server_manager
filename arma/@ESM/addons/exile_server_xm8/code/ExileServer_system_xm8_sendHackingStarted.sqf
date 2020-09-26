/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		XM8 Notification for Hacking
*/
 
private["_recipients", "_territoryName"];
_recipients = _this getVariable ["ExileTerritoryBuildRights", []];
_territoryName = _this getVariable ["ExileTerritoryName", ""];
["hack-started", _recipients, _territoryName, _this getVariable ["ExileDatabaseID", -1]] call ExileServer_system_xm8_send;