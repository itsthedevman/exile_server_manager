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
		{ "logging_add_player_to_territory", "ESM_Logging_AddPlayerToTerritory" },
		{ "logging_channel_id", "ESM_LoggingChannelID" },
		{ "logging_demote_player", "ESM_Logging_DemotePlayer" },
		{ "logging_exec", "ESM_Logging_Exec" },
		{ "logging_gamble", "ESM_Logging_Gamble" },
		{ "logging_modify_player", "ESM_Logging_ModifyPlayer" },
		{ "logging_pay_territory", "ESM_Logging_PayTerritory" },
		{ "logging_promote_player", "ESM_Logging_PromotePlayer" },
		{ "logging_remove_player_from_territory", "ESM_Logging_RemovePlayerFromTerritory" },
		{ "logging_reward_player", "ESM_Logging_RewardPlayer" },
		{ "logging_transfer_poptabs", "ESM_Logging_TransferPoptabs" },
		{ "logging_upgrade_territory", "ESM_Logging_UpgradeTerritory" },
		{ "server_id", "ESM_ServerID" },
		{ "taxes_territory_payment", "ESM_Taxes_TerritoryPayment" },
		{ "taxes_territory_upgrade", "ESM_Taxes_TerritoryUpgrade" },
		{ "territory_admin_uids", "ESM_TerritoryAdminUIDs" },
		{ "version", "ESM_Version" }
	};
};
