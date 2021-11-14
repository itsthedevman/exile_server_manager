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

private _id = _this select 0;
private _dataType = _this param [1, "empty", [""]];
private _data = _this param [2, [], [[], HASH_TYPE]];
private _metadataType = _this param [3, "empty", [""]];
private _metadata = _this param [4, [], [[], HASH_TYPE]];
private _errorMessages = _this param [5, []];

private _errors = [];
{
	private _content = _x;

	// Check the data
	if (count(_content) < 1) then { continue; };
	if !(_content isEqualType "") then { continue; };

	_errors pushBack _content;
}
forEach _errorMessages;


if (_data isEqualType HASH_TYPE) then
{
	_data = _data toArray false;
};

if (_metadata isEqualType HASH_TYPE) then
{
	_metadata = _metadata toArray false;
};

// Send it!
["event", _id, _data, _metadata, _errors] call ESMs_system_extension_call;

true
