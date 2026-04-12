private _result = "esm_updater" callExtension ["check_update", []];

// arma-rs returned a non-zero code (e.g. handler returned Err, argument
// deserialization failed, etc.)
if ((_result select 1) > 0) exitWith {
    diag_log format [
        "[Exile Server Manager Updater] Extension error during check_update (code: %1): %2",
        _result select 1,
        _result select 0
    ];
};

// Arma itself had a problem calling the extension (not found, output too
// large, etc.)
if ((_result select 2) > 0) exitWith {
    diag_log format [
        "[Exile Server Manager Updater] Arma error during check_update (code: %1)",
        _result select 2
    ];
};

diag_log format ["[Exile Server Manager Updater] %1", _result select 0];

true
