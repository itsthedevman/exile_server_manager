/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Calls the ESM DLL and returns the resulting array
*/

// { "KEY": VALUE, "KEY": VALUE }
private _package = "{";

if (count(_this select 1) > 0) then
{
	// ["KEY", VALUE]
	{
		private _text = format['"%1":', _x select 0];

		switch (typeName (_x select 1)) do
		{
			case "STRING":
			{
				_text = format['%1"%2"', _text, _x select 1];
			};

			case "ARRAY":
			{
				_text = format['%1"%2"', _text, format["%1", _x select 1] call ExileClient_util_string_escapeJSON];
			};

			default
			{
				_text = format['%1%2', _text, _x select 1];
			};
		};

		_package = format['%1%2,',_package, _text];
	}
	foreach (_this select 1);

	_package = _package select [0, count(_package) - 1];
};

_package = format['%1}', _package];

parseSimpleArray("ESM" callExtension [_this select 0, [_package]])
