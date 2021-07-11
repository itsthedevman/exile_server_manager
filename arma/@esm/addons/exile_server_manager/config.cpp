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
			file = "\exile_server_manager\bootstrap";

			class preInit { preInit = 1; };
		};
	};
};
