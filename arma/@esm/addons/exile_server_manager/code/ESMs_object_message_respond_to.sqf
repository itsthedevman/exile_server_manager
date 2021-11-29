/**
 *
 * Function:
 *      ESMs_object_message_respond_to
 *
 * Description:
 *      Used to respond to a incoming message with data, or to just say "ack". Every incoming message must be acknowledged, at the very least.
 *
 * Arguments:
 *      _id				-	<String> The ID of the message to respond to.
 *		_dataType		-	<String> The type of data that the outgoing message will hold. Defaults to "empty"
 *		_data			-	<HashMap, Array> The data to send along with the outgoing message. Defaults to []
 *		_metadataType	-	<String> The type of metadata that the outgoing message will hold. Defaults to "empty"
 *		_metadata		-	<HashMap, Array> The metadata to send along with the outgoing message. Defaults to []
 *		_errors		 	-	<Array<String>> An array of error messages. Defaults to []
 *
 * Examples:
 *      ["id"] call ESMs_object_message_respond_to; // ack the message.
 *
 *		[
 *			"id",
 * 			"data_type"
 *			[["key", "value"], ["key", "value"]],
 *			"metadata_type",
 *			[["key", "value"], ["key", "value"]],
 *			["error_message"]
 *		] call ESMs_object_message_respond_to;
 *
 * * *
 *
 * Exile Server Manager
 * www.esmbot.com
 * © 2018-2021 Bryan "WolfkillArcadia"
 *
 * This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License.
 * To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-sa/4.0/.
 *
 **/

params [
	"_id",
	["_type", "event", [""]],
	["_dataType", "empty", [""]],
	["_data", [], [[], HASH_TYPE]],
	["_metadataType", "empty", [""]],
	["_metadata", [], [[], HASH_TYPE]],
	["_errorMessages", []]
];

// Add check for hashmap or hashmap syntax

// Do not convert empty arrays
if (_data isEqualType ARRAY_TYPE && { count(_data) > 0 }) then
{
	_data = _data call ESMs_util_hashmap_fromArray;
};

if (_metadata isEqualType ARRAY_TYPE && { count(_metadata) > 0 }) then
{
	_metadata = _metadata call ESMs_util_hashmap_fromArray;
};

// Process the errors
private _errors = [];
{
	private _content = _x;

	// Check the data
	if (count(_content) < 1) then { continue; };
	if !(_content isEqualType "") then { continue; };

	_errors pushBack _content;
}
forEach _errorMessages;

// Send it!
["send_message", _id, _type, [_dataType, _data], [_metadataType, _metadata], _errors] call ESMs_system_extension_call;

true
