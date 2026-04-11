class CfgPatches
{
	class ESM_Updater
	{
		requiredVersion = 0.1;
		requiredAddons[] = { "exile_server" };
		units[] = {};
		weapons[] = {};
		magazines[] = {};
		ammo[] = {};
	};
};


class CfgFunctions
{
	class ESM_Updater
	{
		class Bootstrap
		{
			class preInit
			{
				file = os_path!("esm_updater", "bootstrap", "fn_preInit.sqf");
				preInit = 1;
			};
		};
	};
};
