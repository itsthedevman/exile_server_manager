class CfgPatches
{
	class exile_server_overwrites
	{
		requiredVersion = 0.1;
		requiredAddons[] = {};
		units[] = {};
		weapons[] = {};
		magazines[] = {};
		ammo[] = {};
	};
};

// Overwrites :D
class CfgFunctions
{
	class ExileServer
	{
		class Bootstrap
		{
			class preInit { preInit = 1; };
		};
	};
};
