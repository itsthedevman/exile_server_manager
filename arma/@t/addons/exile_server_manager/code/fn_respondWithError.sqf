params ["_commandID", ["_errorMessage", "not provided", [""]]];

[_commandID, [["error_message", _errorMessage]]] call ESM_fnc_respond;
