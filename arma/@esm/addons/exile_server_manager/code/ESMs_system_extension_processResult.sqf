/**
 *
 * Function:
 *      ESMs_system_extension_processResult
 *
 * Description:
 *      Processes the result from a callExtension. This function also handles chunked messages, making extra calls to the extension if need be.
 *
 * Arguments:
 *      _this 	-	This can be a stringified simpleArray or an array. Either one needs to be [id, status_code, content].
 * 						id 			- <String, nil> If the message has multiple parts, this is the chunking ID. Used to retrieve the next chunk.
 *						status_code - <Scalar> 		One of the following options:
 * 														-1: An error occurred. The error will be the value for "content".
 *														0: Success/No more chunks.
 *														1: Has more chunks.
 * 						content		- <String> 		The data with this message. If the status_code is -1, this will be the error message.
 *
 * Examples:
 *      [nil, 0, "data"] call ESMs_system_extension_processResult;
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

private _result = _this;

// The extension sends back a empty string after receiving a call
if (isNil("_result") || { _result isEqualTo "" }) exitWith {};

if (_result isEqualType "") then
{
	_result = parseSimpleArray _result;
};

if (_result isEqualTo []) exitWith
{
	["processResult", format["Failed to parse %1", _this], "error"] call ESMs_util_log;
};

private _id = _result select 0;
private _statusCode = _result select 1;
private _content = _result select 2;

// Success with nothing more to retrieve. Return it
if (_statusCode isEqualTo 0) exitWith { _content };

// There was an error
if (_statusCode isEqualTo -1) exitWith
{
	["processResult", format["Status code -1 returned. Content: %1", _content], "error"] call ESMs_util_log;
	nil
};
