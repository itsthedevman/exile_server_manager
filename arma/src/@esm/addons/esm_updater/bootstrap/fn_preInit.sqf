/* ----------------------------------------------------------------------------
Function:
    ESM_Updater_fnc_preInit

Description:
    Asks the updater extension to check for a new ESM extension, then writes whatever came back to the RPT.

    This runs from its own addon rather than from ESM's preInit because of when it runs, not what it does. By the
    time exile_server_manager starts, Arma has already loaded esm_x64.so/dll into the process, and a loaded
    extension cannot be replaced. This addon loads first, while that file is still just a file on disk, and that
    gap is the only reason the updater is split out at all.

    The extension fails open on everything: a dead host, a bad signature, a failed checksum, or a blown deadline
    all come back as an ordinary status string and the server carries on booting. So there is nothing here to
    react to and nothing to abort on. The two exitWith branches below are for the call itself going wrong rather
    than the check, and even those only log.

    Details of a failure land in @esm/log/updater.log. The RPT gets the one-line summary.

Parameters:
    _this - [Nothing]

Returns:
    Nothing

Examples:
    (begin example)

        [] call ESM_Updater_fnc_preInit;

    (end)

Author:
    Exile Server Manager
    www.esmbot.com
    © 2018-current_year!() Bryan "WolfkillArcadia"

    This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
    To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.
---------------------------------------------------------------------------- */

private _result = "esm_updater" callExtension ["check_update", []];

// arma-rs returned a non-zero code (e.g. handler returned Err, argument deserialization failed, etc.)
if ((_result select 1) > 0) exitWith {
    diag_log format [
        "[Exile Server Manager Updater] Extension error during check_update (code: %1): %2",
        _result select 1,
        _result select 0
    ];
};

// Arma itself had a problem calling the extension (not found, output too large, etc.)
if ((_result select 2) > 0) exitWith {
    diag_log format [
        "[Exile Server Manager Updater] Arma error during check_update (code: %1)",
        _result select 2
    ];
};

diag_log format ["[Exile Server Manager Updater] %1", _result select 0];

true
