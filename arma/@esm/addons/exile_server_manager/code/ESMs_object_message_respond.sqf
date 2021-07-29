/**
 *
 * Function:
 *      ESMs_object_message_respond
 *
 * Description:
 *      Used to respond to a incoming message with data, or to just say "ack". Every incoming message must be acknowledged, at the very least.
 *
 * Arguments:
 *      _id				-	<String> The ID of the message to respond to.
 *		_data			-	<[String, HashMap]> The String represents the HashMap's context when the extension reads the data.
 *												For programmers, the String is the name of the struct and the Hashmap is the data to be deserialized.
 *		_metadata		-	<[String, HashMap]> The same as _data, but for metadata
 *		_errors		 	-	<[[String, String]...]> Any errors to send in response to the message. Each entry in the array must contain the type
 *													and content, in that order. Valid types:
 *														"code" 		- Treats the content as an locale code
 *														"message"	- Treats the content as a free form message.
 *
 * Examples:
 *      ["id"] call ESMs_object_message_respond; // ack the message.
 *
 *		[
 *			"id",
 *			[[
 *	 			"data_type",
 *				[["key", "value"], ["key", "value"]]
 * 			]],
 *			[[
 *	 			"metadata_type",
 *				[["key", "value"], ["key", "value"]]
 * 			]],
 *			[["error_type", "error_content"], ["error_type", "error_content"]]
 *		] call ESMs_object_message_respond;
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
private _data = _this param [1, ["empty", []]]; // Default to an acknowledge event
private _metadata = _this param [2, ["empty", []]];
private _errors = _this param [3, []];

// If sent as is, _errors will be treated as a HashMap by the parser, with "error_type" as the keys.
// This will cause a bug if there are more than one entries for the same type.
// Instead, group them by their type and send them that way. Shame Arma can't do this.
private _errorsWrapper = createHashMapFromArray [["code", []], ["message", []]];

{
	private _type = _x select 0;
	private _content = _x select 1;

	// Ensure the type is valid
	if !(_type in _errorsWrapper) then { continue; };

	// Ensure there's data
	if (count(_content) < 1) then { continue; };

	// Add to the list
	private _items = _errorsWrapper get _type;
	_items pushBack _content;

	// And save it
	_errorsWrapper set [_type, _items];
}
forEach _errors;

// Send it!
["event", _id, _data, _metadata, _errorsWrapper] call ESMs_system_extension_call;

true
