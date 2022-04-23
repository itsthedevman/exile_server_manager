/* ----------------------------------------------------------------------------
Function: ESMs_object_message_respond_to

Description:
	Used to respond to a incoming message with data, or to just say "ack". Every incoming message must be acknowledged, at the very least.

Parameters:
	_id				- The ID of the message to respond to. [String]
	_dataType		- The type of data that the outgoing message will hold. Defaults to "empty". [String]
	_data			- The data to send along with the outgoing message. Defaults to []. [HashMap, Array]
	_metadataType	- The type of metadata that the outgoing message will hold. Defaults to "empty". [String]
	_metadata		- The metadata to send along with the outgoing message. Defaults to []. [HashMap, Array]
	_errors		 	- An array of error objects. Defaults to []. [Array<HashMap>]

Returns:
	The response from the extension which defaults to ""

Examples:
	(begin example)

	// ack the message.
	["id"] call ESMs_object_message_respond_to;

	// Or send a message with everything
	[
		"id",
		"data_type"
		[
			["data_key_1", "data_key_2"],
			["data_value_1", "data_value_2"]
		],
		"metadata_type",
		[
			["metadata_key_1", "metadata_key_2"],
			["metadata_value_1", "metadata_value_2"]
		],
		[
			[
				["type", "content"],
				["code", "ERROR_CODE"]
			],
			[
				["type", "content"],
				["message", "This is an error message"]
			]
		]
	] call ESMs_object_message_respond_to;

	(end)

Author:
	Exile Server Manager
	www.esmbot.com
	© 2018-2022 Bryan "WolfkillArcadia"

	This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
---------------------------------------------------------------------------- */

params [
	"_id",
	["_type", "event", [""]],
	["_dataType", "empty", [""]],
	["_data", [], [[], HASH_TYPE]],
	["_metadataType", "empty", [""]],
	["_metadata", [], [[], HASH_TYPE]],
	["_errors", [], [[]]]
];

// Errors must be hashmaps or hashmap arrays
private _errorPackage = [];
{
	if (isNil "_x") then { continue; };
	if !(_x isEqualType HASH_TYPE || _x call ESMs_util_array_isValidHashmap) then { continue; };

	_errorPackage pushBack _x;
}
forEach _errors;

// Send it!
[
	"send_message",
	_id,
	_type,
	[
		["type", "content"],
		[
			_dataType,
			if (_dataType isEqualTo "empty") then { nil } else { _data }
		]
	],
	[
		["type", "content"],
		[
			_metadataType,
			if (_metadataType isEqualTo "empty") then { nil } else { _metadata }
		]
	],
	_errorPackage
]
call ESMs_system_extension_call
