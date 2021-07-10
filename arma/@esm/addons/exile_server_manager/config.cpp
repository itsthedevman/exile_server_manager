class CfgPatches
{
	class ESM
	{
		requiredVersion = 0.1;
		requiredAddons[] = {
			"exile_server",
			"exile_client"
		};
		units[] = {};
		weapons[] = {};
		magazines[] = {};
		ammo[] = {};
	};
};

class CfgFunctions
{
	class ESM
	{
		class Functions
		{
			file = "\exile_server_manager\code";

			// Initialization
			class preInit { preInit = 1; };

			// Code
			class payTerritory {};
			class promotePlayer {};
			class demotePlayer {};
			class addPlayerToTerritory {};
			class removePlayerFromTerritory {};
			class upgradeTerritory {};
			class gamble{};
			class modifyPlayer {};
			class postServerInitialization {};
			class exec{};
			class reward{};
			class transferPoptabs{};

			// Utils
			class log {};
			class getFlagObject {};
			class callExtension {};
			class sendToChannel {};
			class hasAccessToTerritory {};
			class logToDiscord {};
			class scalarToString {};
			class logToDLL {};
			class attemptReconnect {};
			class respond {};
			class ping {};
			class incrementPaymentCounter {};
			class resetPaymentCounter {};
			class handleCallback {};
			class respondWithErrorCode {};
			class respondWithError {};
		};
	};
};
