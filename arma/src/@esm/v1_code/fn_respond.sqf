params ["_commandID", ["_response", [], [[]]]];

["respond", _commandID, _response] call ESM_fnc_callExtension;
