_playerUID = _this;
_playerObject = objNull;

{
	if ((_x getVariable ["ExileOwnerUID", ""]) isEqualTo _playerUID) exitWith
	{
		_playerObject = _x;
	};
}
forEach ([0, 0, 0] nearEntities ["Exile_Unit_Player", 1000000]);

_playerObject
