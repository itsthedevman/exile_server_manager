/* ----------------------------------------------------------------------------
Function:
	ESMs_util_log

Description:
 	If you haven't guessed, it logs a message based on it's severity. See argument "_logLevel" for more details

Parameters:
    _caller     -   [String] The name of the function whom called this log.
    _message    -   [Any] The message to log
    _logLevel   -   [String] The level this log should be visible.
                    Valid options are "trace", "debug", "info", "warn", "error". Default: "info"
                    This follows the standard followed by most logging frameworks. If the current log level is:
                        "error"     - Logs "error" only
                        "warn"      - Logs "warn" and above
                        "info"      - Logs "info" and above
                        "debug"     - Logs "debug" and above
                        "trace"     - Logs "trace" and above

Returns:
	Nothing

Examples:
	(begin example)

		["myFunction", "This is a error!", "error"] call ESMs_util_log;
        ["myFunction", "This is a warning!", "warn"] call ESMs_util_log;
        ["myFunction", "This is a log!", "info"] call ESMs_util_log;
        ["myFunction", "This is a debug log!", "debug"] call ESMs_util_log;
        ["myFunction", "This is a trace log!", "trace"] call ESMs_util_log;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2023 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

private _caller = _this select 0;
private _message = _this select 1;
private _logLevel = _this param [2, "info"];

// Make sure it's a string
if (!type?(_message, STRING)) then
{
	_message = str(_message);
};

// Skip everything else and let the extension handle it
if (ESM_LogOutput isEqualTo "extension") exitWith
{
	// Do not use ESMs_system_extension_call
	"esm" callExtension ["log", [toLowerANSI(_logLevel), _caller, _message]];
	nil
};

// error: 0, warn: 1, info: 2, debug: 3, trace: 4
private _inputLogLevel = get!(ESM_LogLevelLookup, _logLevel, 2);
private _currentLogLevel = get!(ESM_LogLevelLookup, ESM_LogLevel, 2);

// Only log if the log level allows it
if (_inputLogLevel > _currentLogLevel) exitWith {};

switch (ESM_LogOutput) do
{
	case "both":
	{
		diag_log format["%1 | %2 - %3", toUpperANSI(_logLevel), _caller, _message];
		"esm" callExtension ["log", [toLowerANSI(_logLevel), _caller, _message]];
	};

	default
	{
		diag_log format["%1 | %2 - %3", toUpperANSI(_logLevel), _caller, _message];
	};
};

nil
