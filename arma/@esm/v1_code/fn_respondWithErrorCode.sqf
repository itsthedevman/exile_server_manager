params ["_commandID", ["_errorCode", "unprovided", [""]]];

[_commandID, [["error_code", _errorCode]]] call ESM_fnc_respond;
