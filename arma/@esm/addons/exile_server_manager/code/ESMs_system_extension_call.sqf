/**
 * ESM_system_extension_call
 * 	Calls the extension function, passing in any arguments
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 WolfkillArcadia
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 */

// If the argument is a string, we're trying to directly call a function with no arguments
if (_this isEqualType "") exitWith { "esm" callExtension _this };

// The argument is an array
private _function = _this select 0;
private _arguments = _this select [1, count(_this) - 1];
private _sanitizedPackage = [];

// Cache a sanitizer function that escapes any JSON unsafe strings
private _sanitizer = {
	private _package = _this select 0;
	private _item = _this select 1;

	switch (typeName(_item)) do
	{
		case "ARRAY":
		{
			private _tempPackage = [];

			{
				[_tempPackage, _x] call _sanitizer;
			}
			forEach _item;

			_package pushBack _tempPackage;
		};

		case "STRING":
		{
			_package pushBack (_item call ExileClient_util_string_escapeJson);
		};

		default
		{
			_package pushBack _item;
		};
	};
};

// Using the saniziter, sanitize the package
{
	[_sanitizedPackage, _x] call _sanitizer;
}
forEach _arguments;

// Call the extension and return the result
"esm" callExtension [_function, _sanitizedPackage]
