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
		{ "ESM_ServerID", "STRING", },
		{ "ESM_CommunityID", "STRING" },
		{ "ESM_UseExtDB3", "BOOL" },
		{ "ESM_TerritoryManagementUIDs", "ARRAY" },
		{ "ESM_Logging_AddPlayerToTerritory", "BOOL" },
		{ "ESM_Logging_PayTerritory", "BOOL" },
		{ "ESM_Logging_PromotePlayer", "BOOL" },
		{ "ESM_Logging_RemovePlayerFromTerritory", "BOOL" },
		{ "ESM_Logging_UpgradeTerritory", "BOOL" },
		{ "ESM_Logging_DemotePlayer", "BOOL" },
		{ "ESM_Logging_ModifyPlayer", "BOOL" },
		{ "ESM_Logging_Gamble", "BOOL" },
		{ "ESM_Logging_Exec", "BOOL" },
		{ "ESM_Logging_RewardPlayer", "BOOL" },
		{ "ESM_Logging_TransferPoptabs", "BOOL" },
		{ "ESM_GambleWinPercentage", "SCALAR" },
		{ "ESM_GamblePayoutRandomizerMin", "SCALAR" },
		{ "ESM_GamblePayoutRandomizerMid", "SCALAR" },
		{ "ESM_GamblePayoutRandomizerMax", "SCALAR" },
		{ "ESM_GamblePayoutPercentage", "SCALAR" },
		{ "ESM_GamblePayoutModifier", "SCALAR" },
		{ "ESM_PayTaxPercentage", "SCALAR" },
		{ "ESM_UpgradeTaxPercentage", "SCALAR" },
		{ "ESM_RewardPoptabsPlayer", "SCALAR" },
		{ "ESM_RewardPoptabsLocker", "SCALAR" },
		{ "ESM_RewardRespect", "SCALAR" },
		{ "ESM_RewardItems", "ARRAY" }
	};
};
