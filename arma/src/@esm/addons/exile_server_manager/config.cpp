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
				file = os_path!("exile_server_manager", "bootstrap", "fn_preInit.sqf");
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
		{ "build_number", "ESM_BuildNumber" },
		{ "community_id", "ESM_CommunityID" },
		{ "extdb_version", "ESM_ExtDBVersion" },
		{ "gambling_locker_limit_enabled", "ESM_Gambling_LockerLimitEnabled" },
		{ "gambling_modifier", "ESM_Gambling_Modifier" },
		{ "gambling_payout_base", "ESM_Gambling_PayoutBase" },
		{ "gambling_payout_randomizer_max", "ESM_Gambling_PayoutRandomizerMax" },
		{ "gambling_payout_randomizer_mid", "ESM_Gambling_PayoutRandomizerMid" },
		{ "gambling_payout_randomizer_min", "ESM_Gambling_PayoutRandomizerMin" },
		{ "gambling_win_percentage", "ESM_Gambling_WinPercentage" },
		{ "logging_channel_id", "ESM_LoggingChannelID" },
		{ "logging_command_add", "ESM_Logging_CommandAdd" },
		{ "logging_command_demote", "ESM_Logging_CommandDemote" },
		{ "logging_command_sqf", "ESM_Logging_CommandSqf" },
		{ "logging_command_gamble", "ESM_Logging_CommandGamble" },
		{ "logging_command_player", "ESM_Logging_CommandPlayer" },
		{ "logging_command_pay", "ESM_Logging_CommandPay" },
		{ "logging_command_promote", "ESM_Logging_CommandPromote" },
		{ "logging_command_remove", "ESM_Logging_CommandRemove" },
		{ "logging_command_reward", "ESM_Logging_CommandReward" },
		{ "logging_command_transfer", "ESM_Logging_CommandTransfer" },
		{ "logging_command_upgrade", "ESM_Logging_CommandUpgrade" },
		{ "server_id", "ESM_ServerID" },
		{ "taxes_territory_payment", "ESM_Taxes_TerritoryPayment" },
		{ "taxes_territory_upgrade", "ESM_Taxes_TerritoryUpgrade" },
		{ "territory_admin_uids", "ESM_TerritoryAdminUIDs" },
		{ "version", "ESM_Version" }
	};
};
