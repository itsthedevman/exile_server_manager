/*
	Exile Server Manager
	www.esmbot.com
	© 2018 Exile Server Manager Team
	This work is licensed under the Creative Commons Attribution-NonCommercial-NoDerivatives 4.0 International License. 
	To view a copy of this license, visit http://creativecommons.org/licenses/by-nc-nd/4.0/.

	Description:
		Threaded loop that consistenly checks if the website has a request. This is written for speed, not readability. 
*/

// Send a request to the DLL for a task
private _return = ["request_check", []] call ESM_fnc_callExtension;

// Make sure we have something to process
if (!(_return select 0)) exitWith {};

// Get the function
private _function = (_return select 1) select 0;

// Remove the function
(_return select 1) deleteAt 0; 

// Get the parameters
private _parameters = _return select 1;

// Make sure the function is compiled
if (missionNameSpace getVariable [_function, ""] isEqualTo "") exitWith 
{
	["fn_checkForRequests", format["Function %1 called by ESM but it wasn't compiled", _function]] call ESM_fnc_log; 
};

// I do NOT want this to be blocking. so it means we want to get the hell off this thread ASAP so it can process the next request
_parameters spawn (missionNamespace getVariable [_function, {}]);

true


