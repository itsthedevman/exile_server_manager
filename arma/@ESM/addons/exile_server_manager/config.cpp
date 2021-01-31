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
			file = "exile_server_manager\code";

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
			class rewardPlayer{};
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
		};
	};
};

class CfgESM
{
	// Setting variables retrieved from server settings
	// Do not modify these as you will severely break ESM on your server!
	globalVariables[] =
	{
		"ESM_CommunityID",
		"ESM_ExtDBVersion",
		"ESM_Gambling_Modifier",
		"ESM_Gambling_PayoutBase",
		"ESM_Gambling_PayoutRandomizerMax",
		"ESM_Gambling_PayoutRandomizerMid",
		"ESM_Gambling_PayoutRandomizerMin",
		"ESM_Gambling_WinPercentage",
		"ESM_Logging_AddPlayerToTerritory",
		"ESM_Logging_DemotePlayer",
		"ESM_Logging_Exec",
		"ESM_Logging_Gamble",
		"ESM_Logging_ModifyPlayer",
		"ESM_Logging_PayTerritory",
		"ESM_Logging_PromotePlayer",
		"ESM_Logging_RemovePlayerFromTerritory",
		"ESM_Logging_RewardPlayer",
		"ESM_Logging_TransferPoptabs",
		"ESM_Logging_UpgradeTerritory",
		"ESM_RewardItems",
		"ESM_RewardLockerPoptabs",
		"ESM_RewardPlayerPoptabs",
		"ESM_RewardRespect",
		"ESM_ServerID",
		"ESM_Taxes_TerritoryPayment",
		"ESM_Taxes_TerritoryPayment",
		"ESM_TerritoryAdminUIDs"
	};
};
