/*
	fn_scalarToString
	© 2018 Andrew_S90
	All Rights Reserved

	Permission given by Andrew_S90 for use within Exile Server Manager
	Description:
		Converts a scalar to a string and makes it look pretty
*/
private _input = _this;
private _output = [];
private _isNegative = _input < 0;

if (_isNegative) then 
{
	_input = abs(_input);
};

private _popTabsString = _input call ExileClient_util_string_exponentToString;
private _split = _popTabsString splitString "";
reverse _split;

{
	if (((_forEachIndex % 3) isEqualTo 0) && !(_forEachIndex isEqualTo 0)) then 
	{
		_output pushBack ",";
	};
	_output pushBack _x;
} 
forEach _split;

reverse _output;

_output = _output joinString "";

if (_isNegative) then 
{
	format["-%1", _output]
}
else
{
	_output
};