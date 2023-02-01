class CfgPatches
{
	class ExileServerManager
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
	class ExileServerManager
	{
		class Bootstrap
		{
			class preInit
			{
				file = os_path!("exile_server_manager", "bootstrap", "preInit.sqf");
				preInit = 1;
			};
		};
	};
};

class CfgESM
{
	// A safelist of variables to be extracted from the provided data on postInit.
	// Do not modify these! You will break ESM.
	globalVariables[] =
	{
		"ESM_BuildNumber",
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
		"ESM_LoggingChannelID",
		"ESM_ServerID",
		"ESM_Taxes_TerritoryPayment",
		"ESM_Taxes_TerritoryUpgrade",
		"ESM_TerritoryAdminUIDs",
		"ESM_Version"
	};
};
