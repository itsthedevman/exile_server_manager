/* ----------------------------------------------------------------------------
Function:
  ESMs_system_account_isKnown

Description:
  Checks if a UID has joined this server or not

Parameters:
  _this - [String] The UID to check

Returns:
  true/false

Examples:
  (begin example)

    "765560000000000000" call ESMs_system_account_isKnown; // false

  (end)

Author:
  Exile Server Manager
  www.esmbot.com
  © 2018-current_year!() Bryan "WolfkillArcadia"

  This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
  To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

format["isKnownAccount:%1", _this] call ExileServer_system_database_query_selectSingleField
