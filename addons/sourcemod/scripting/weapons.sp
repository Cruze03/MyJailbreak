#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <wardn>
#include <colors>
#include <autoexecconfig>

#define VERSION "0.x"

Handle Timers[MAXPLAYERS + 1] = null;

bool newWeaponsSelected[MAXPLAYERS+1];
bool rememberChoice[MAXPLAYERS+1];
bool weaponsGivenThisRound[MAXPLAYERS + 1] = { false, ... };

// Menus
Handle optionsMenu1 = null;
Handle optionsMenu2 = null;
Handle optionsMenu3 = null;
Handle optionsMenu4 = null;

char primaryWeapon[MAXPLAYERS + 1][24];
char secondaryWeapon[MAXPLAYERS + 1][24];

ConVar gc_bTag;
ConVar gc_bSpawn;
ConVar gc_bPlugin;
ConVar gc_bTerror;
ConVar gc_bCTerror;
ConVar gc_bTA;
ConVar gc_bHealth;

enum weapons
{
	String:ItemName[64],
	String:desc[64]
}

Handle array_primary;
Handle array_secondary;

public Plugin:myinfo =
{
	name = "Jailbreak Weapons",
	author = "shanapu, franug",
	description = "plugin",
	version = VERSION,
	url = "http://www.shanapu.de/"
};

Handle weapons1 = null;
Handle weapons2 = null;
//Handle remember = null;

public void OnPluginStart()
{
	
	LoadTranslations("MyJailbreakWeapons.phrases");

	array_primary = CreateArray(128);
	array_secondary = CreateArray(128);
	ListWeapons();
	
	// Create menus
	optionsMenu1 = BuildOptionsMenu(true);
	optionsMenu2 = BuildOptionsMenu(false);
	optionsMenu3 = BuildOptionsMenuWeapons(true);
	optionsMenu4 = BuildOptionsMenuWeapons(false);
	
	HookEvent("player_spawn", Event_PlayerSpawn);

	AutoExecConfig_SetFile("MyJailbreak_weapons");
	AutoExecConfig_SetCreateFile(true);
	
	gc_bPlugin = AutoExecConfig_CreateConVar("sm_weapons_enable", "1", "0 - disabled, 1 - enable weapons");
	gc_bTerror = AutoExecConfig_CreateConVar("sm_weapons_t", "0", "0 - disabled, 1 - enable weapons for T");
	gc_bCTerror = AutoExecConfig_CreateConVar("sm_weapons_ct", "1", "0 - disabled, 1 - enable weapons for CT");
	gc_bSpawn = AutoExecConfig_CreateConVar("sm_weapons_spawnmenu", "1", "0 - disabled, 1 - enable open menu on spawn");
	gc_bTA = AutoExecConfig_CreateConVar("sm_weapons_warden_tagrenade", "1", "0 - disabled, 1 - enable open menu on spawn");
	gc_bHealth = AutoExecConfig_CreateConVar("sm_weapons_warden_healthshot", "1", "0 - disabled, 1 - enable open menu on spawn");
	gc_bTag = AutoExecConfig_CreateConVar("sm_weapons_tag", "1", "Allow \"MyJailbreak\" to be added to the server tags? So player will find servers with MyJB faster. it dont touch you sv_tags", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	AutoExecConfig_CacheConvars();
	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	AutoExecConfig(true, "MyJailbreak_weapons");
	
	RegConsoleCmd("sm_guns", Cmd_Weapons);
	RegConsoleCmd("sm_gun", Cmd_Weapons);
	RegConsoleCmd("sm_weapon", Cmd_Weapons);
	RegConsoleCmd("sm_weapons", Cmd_Weapons);
	RegConsoleCmd("sm_arms", Cmd_Weapons);
	RegConsoleCmd("sm_firearms", Cmd_Weapons);
	RegConsoleCmd("sm_gunmenu", Cmd_Weapons);
	RegConsoleCmd("sm_weaponmenu", Cmd_Weapons);
	RegConsoleCmd("sm_give", Cmd_Weapons);
	RegConsoleCmd("sm_giveweapon", Cmd_Weapons);

	
	weapons1 = RegClientCookie("Primary Weapons", "", CookieAccess_Private);
	weapons2 = RegClientCookie("Secondary Weapons", "", CookieAccess_Private);
	//remember = RegClientCookie("Remember Weapons", "", CookieAccess_Private);
}

public void OnConfigsExecuted()
{
	
	if (gc_bTag.BoolValue)
	{
		ConVar hTags = FindConVar("sv_tags");
		char sTags[128];
		hTags.GetString(sTags, sizeof(sTags));
		if (StrContains(sTags, "MyJailbreak", false) == -1)
		{
			StrCat(sTags, sizeof(sTags), ", MyJailbreak");
			hTags.SetString(sTags);
		}
	}
}

Handle:BuildOptionsMenu(bool:sameWeaponsEnabled)
{
	char info1[255], info2[255], info3[255], info4[255], info5[255], info6[255];


	int sameWeaponsStyle = (sameWeaponsEnabled) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED;
	Handle menu3 = CreateMenu(Menu_Options);
	Format(info1, sizeof(info1), "%T\n ", "weapons_info_Title", LANG_SERVER);
	SetMenuTitle(menu3, info1);
	SetMenuExitButton(menu3, true);
	Format(info2, sizeof(info2), "%T", "weapons_info_choose", LANG_SERVER);
	AddMenuItem(menu3, "New", info2);
	Format(info3, sizeof(info3), "%T", "weapons_info_same", LANG_SERVER);
	AddMenuItem(menu3, "Same 1", info3, sameWeaponsStyle);
	Format(info4, sizeof(info4), "%T", "weapons_info_sameall", LANG_SERVER);
	AddMenuItem(menu3, "Same All", info4, sameWeaponsStyle);
	Format(info5, sizeof(info5), "%T", "weapons_info_random", LANG_SERVER);
	AddMenuItem(menu3, "Random 1", info5);
	Format(info6, sizeof(info6), "%T", "weapons_info_randomall", LANG_SERVER);
	AddMenuItem(menu3, "Random All", info6);
	return menu3;
}

DisplayOptionsMenu(clientIndex)
{
	if (strcmp(primaryWeapon[clientIndex], "") == 0 || strcmp(secondaryWeapon[clientIndex], "") == 0)
		DisplayMenu(optionsMenu2, clientIndex, 30);
	else
		DisplayMenu(optionsMenu1, clientIndex, 30);
}

Handle:BuildOptionsMenuWeapons(bool:primary)
{
	char info7[255], info8[255];
	Handle menu;
	int Items[weapons];
	if(primary)
	{
		menu = CreateMenu(Menu_Primary);
		Format(info7, sizeof(info7), "%T\n ", "weapons_info_prim", LANG_SERVER);
		SetMenuTitle(menu, info7);
		SetMenuExitButton(menu, true);
		for(int i=0;i<GetArraySize(array_primary);++i)
		{
			GetArrayArray(array_primary, i, Items[0]);
			AddMenuItem(menu, Items[ItemName], Items[desc]);
		}
	}
	else
	{
		menu = CreateMenu(Menu_Secondary);
		Format(info8, sizeof(info8), "%T\n ", "weapons_info_sec", LANG_SERVER);
		SetMenuTitle(menu, info8);
		SetMenuExitButton(menu, true);
		for(int i=0;i<GetArraySize(array_secondary);++i)
		{
			GetArrayArray(array_secondary, i, Items[0]);
			AddMenuItem(menu, Items[ItemName], Items[desc]);
		}
	}
	
	return menu;

}


public Menu_Options(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		GetMenuItem(menu, param2, info, sizeof(info));
		
		if (StrEqual(info, "New"))
		{
			if (weaponsGivenThisRound[param1])
				newWeaponsSelected[param1] = true;
			DisplayMenu(optionsMenu3, param1, MENU_TIME_FOREVER);
			rememberChoice[param1] = false;
		}
		else if (StrEqual(info, "Same 1"))
		{
			if (weaponsGivenThisRound[param1])
			{
				newWeaponsSelected[param1] = true;
				CPrintToChat(param1, "%t %t", "weapons_tag", "weapons_same");
			}
			GiveSavedWeapons(param1);
			rememberChoice[param1] = false;
		}
		else if (StrEqual(info, "Same All"))
		{
			if (weaponsGivenThisRound[param1])
				CPrintToChat(param1, "%t %t", "weapons_tag", "weapons_sameall");
			GiveSavedWeapons(param1);
			rememberChoice[param1] = true;
		}
		else if (StrEqual(info, "Random 1"))
		{
			if (weaponsGivenThisRound[param1])
			{
				newWeaponsSelected[param1] = true;
				CPrintToChat(param1, "%t %t", "weapons_tag", "weapons_random");
			}
			primaryWeapon[param1] = "random";
			secondaryWeapon[param1] = "random";
			GiveSavedWeapons(param1);
			rememberChoice[param1] = false;
		}
		else if (StrEqual(info, "Random All"))
		{
			if (weaponsGivenThisRound[param1])
				CPrintToChat(param1, "%t %t", "weapons_tag", "weapons_randomall");
			primaryWeapon[param1] = "random";
			secondaryWeapon[param1] = "random";
			GiveSavedWeapons(param1);
			rememberChoice[param1] = true;
		}
	}
}

public Menu_Primary(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		GetMenuItem(menu, param2, info, sizeof(info));
		primaryWeapon[param1] = info;
		DisplayMenu(optionsMenu4, param1, MENU_TIME_FOREVER);
	}
}

public Menu_Secondary(Handle:menu, MenuAction:action, param1, param2)
{
	if (action == MenuAction_Select)
	{
		char info[24];
		GetMenuItem(menu, param2, info, sizeof(info));
		secondaryWeapon[param1] = info;
		GiveSavedWeapons(param1);
		if (!IsPlayerAlive(param1))
			newWeaponsSelected[param1] = true;
		if (newWeaponsSelected[param1])
			CPrintToChat(param1, "%t %t", "weapons_tag", "weapons_next");
	}
}

public void OnMapStart()
{
	SetBuyZones("Disable");
}

public Event_PlayerSpawn(Handle:event, const char[] name, bool:dontBroadcast)
{
	int clientIndex = GetClientOfUserId(GetEventInt(event, "userid"));
	
	//CancelClientMenu(clientIndex);
	DeathTimer(clientIndex);
	if(gc_bSpawn.BoolValue)	
	{
	Timers[clientIndex] = CreateTimer(1.0, GetWeapons, clientIndex);
	}
}

public Action:GetWeapons(Handle:timer, any:clientIndex)
{
	Timers[clientIndex] = null;
	if (GetClientTeam(clientIndex) > 1 && IsPlayerAlive(clientIndex))
	{
	if(gc_bPlugin.BoolValue)	
	{
	if(gc_bTerror.BoolValue)	
	{
	
	
		// Give weapons or display menu.
		weaponsGivenThisRound[clientIndex] = false;
		if (newWeaponsSelected[clientIndex])
		{
			GiveSavedWeapons(clientIndex);
			newWeaponsSelected[clientIndex] = false;
		}
		else if (rememberChoice[clientIndex])
		{
			GiveSavedWeapons(clientIndex);
		}
		else
		{
			DisplayOptionsMenu(clientIndex);
		}
	}else if(GetClientTeam(clientIndex) == 3)
	{
	if(gc_bCTerror.BoolValue)	
	{
	// Give weapons or display menu.
		weaponsGivenThisRound[clientIndex] = false;
		if (newWeaponsSelected[clientIndex])
		{
			GiveSavedWeapons(clientIndex);
			newWeaponsSelected[clientIndex] = false;
		}
		else if (rememberChoice[clientIndex])
		{
			GiveSavedWeapons(clientIndex);
		}
		else
		{
			DisplayOptionsMenu(clientIndex);
		}
	}
	}
	}
	}
}

public Action:Fix(Handle:timer, any:clientIndex)
{
	Timers[clientIndex] = null;
	if (GetClientTeam(clientIndex) > 1 && IsPlayerAlive(clientIndex))
	{
		GiveSavedWeaponsFix(clientIndex);
	}
}

GiveSavedWeaponsFix(clientIndex)
{
	if (IsPlayerAlive(clientIndex))
	{		
		if(gc_bPlugin.BoolValue)
		{
			if(gc_bTerror.BoolValue)
		{
		//StripAllWeapons(clientIndex);
		if(GetPlayerWeaponSlot(clientIndex, CS_SLOT_PRIMARY) == -1)
		{
			if (StrEqual(primaryWeapon[clientIndex], "random"))
			{
				// Select random menu item (excluding "Random" option)
				int random = GetRandomInt(0, GetArraySize(array_primary)-1);
				int Items[weapons];
				GetArrayArray(array_primary, random, Items[0]);
				GivePlayerItem(clientIndex, Items[ItemName]);
			}else GivePlayerItem(clientIndex, primaryWeapon[clientIndex]);
		}
		if(GetPlayerWeaponSlot(clientIndex, CS_SLOT_SECONDARY) == -1)
		{
			if (StrEqual(secondaryWeapon[clientIndex], "random"))
			{
				// Select random menu item (excluding "Random" option)
				int random = GetRandomInt(0, GetArraySize(array_secondary)-1);
				int Items[weapons];
				GetArrayArray(array_secondary, random, Items[0]);
				GivePlayerItem(clientIndex, Items[ItemName]);
			}else GivePlayerItem(clientIndex, secondaryWeapon[clientIndex]);
		}
		if(GetPlayerWeaponSlot(clientIndex, CS_SLOT_GRENADE) == -1) GivePlayerItem(clientIndex, "weapon_hegrenade");
		//GivePlayerItem(clientIndex, "weapon_hegrenade");
		//GivePlayerItem(clientIndex, "weapon_decoy");
		//GivePlayerItem(clientIndex, "weapon_flashbang");
		//GivePlayerItem(clientIndex, "weapon_molotov");
		//GivePlayerItem(clientIndex, "weapon_decoy");
		//GivePlayerItem(clientIndex, "weapon_flashbang");
		//GivePlayerItem(clientIndex, "weapon_molotov");
		weaponsGivenThisRound[clientIndex] = true;
		}else if(GetClientTeam(clientIndex) == 3)
		{
		if(gc_bCTerror.BoolValue)	
		{
		if(GetPlayerWeaponSlot(clientIndex, CS_SLOT_PRIMARY) == -1)
		{
			if (StrEqual(primaryWeapon[clientIndex], "random"))
			{
				// Select random menu item (excluding "Random" option)
				int random = GetRandomInt(0, GetArraySize(array_primary)-1);
				int Items[weapons];
				GetArrayArray(array_primary, random, Items[0]);
				GivePlayerItem(clientIndex, Items[ItemName]);
			}
			else GivePlayerItem(clientIndex, primaryWeapon[clientIndex]);
			}if(GetPlayerWeaponSlot(clientIndex, CS_SLOT_SECONDARY) == -1)
			{
				if (StrEqual(secondaryWeapon[clientIndex], "random"))
				{
					// Select random menu item (excluding "Random" option)
					int random = GetRandomInt(0, GetArraySize(array_secondary)-1);
					int Items[weapons];
					GetArrayArray(array_secondary, random, Items[0]);
					GivePlayerItem(clientIndex, Items[ItemName]);
				}else GivePlayerItem(clientIndex, secondaryWeapon[clientIndex]);
			}if(GetPlayerWeaponSlot(clientIndex, CS_SLOT_GRENADE) == -1) GivePlayerItem(clientIndex, "weapon_hegrenade");
			//GivePlayerItem(clientIndex, "weapon_hegrenade");
			//GivePlayerItem(clientIndex, "weapon_decoy");
			//GivePlayerItem(clientIndex, "weapon_flashbang");
			//GivePlayerItem(clientIndex, "weapon_molotov");
			//GivePlayerItem(clientIndex, "weapon_decoy");
			//GivePlayerItem(clientIndex, "weapon_flashbang");
			//GivePlayerItem(clientIndex, "weapon_molotov");
			weaponsGivenThisRound[clientIndex] = true;
	}
	}
	}
	}
}

SetBuyZones(const char[] status)
{
	int maxEntities = GetMaxEntities();
	char class[24];
	
	for (int i = MaxClients + 1; i < maxEntities; i++)
	{
		if (IsValidEdict(i))
		{
			GetEdictClassname(i, class, sizeof(class));
			if (StrEqual(class, "func_buyzone"))
				AcceptEntityInput(i, status);
		}
	}
}

public Action Cmd_Weapons(int client,int args)
{
	
	if (client != 0 && IsClientInGame(client))
	{
				rememberChoice[client] = false;
				DisplayOptionsMenu(client);
				return Plugin_Handled;
	}
	return Plugin_Continue;
}

GiveSavedWeapons(clientIndex)
{

	if (!weaponsGivenThisRound[clientIndex] && IsPlayerAlive(clientIndex))
	{
		
		StripAllWeapons(clientIndex);
		if (StrEqual(primaryWeapon[clientIndex], "random"))
		{
			// Select random menu item (excluding "Random" option)
			int random = GetRandomInt(0, GetArraySize(array_primary)-1);
			int Items[weapons];
			GetArrayArray(array_primary, random, Items[0]);
			GivePlayerItem(clientIndex, Items[ItemName]);
		}
		else
			GivePlayerItem(clientIndex, primaryWeapon[clientIndex]);

		if (StrEqual(secondaryWeapon[clientIndex], "random"))
		{
			// Select random menu item (excluding "Random" option)
			int random = GetRandomInt(0, GetArraySize(array_secondary)-1);
			int Items[weapons];
			GetArrayArray(array_secondary, random, Items[0]);
			GivePlayerItem(clientIndex, Items[ItemName]);
		}
		else
			GivePlayerItem(clientIndex, secondaryWeapon[clientIndex]);

		if (warden_iswarden(clientIndex))
		{
		if (gc_bHealth .BoolValue)
		{
		GivePlayerItem(clientIndex, "weapon_healthshot");
		CPrintToChat(clientIndex, "%t %t", "weapons_tag", "weapons_health");
		}
		if (gc_bTA.BoolValue)
		{
		GivePlayerItem(clientIndex, "weapon_tagrenade");
		CPrintToChat(clientIndex, "%t %t", "weapons_tag", "weapons_ta");
		}
		}
		
		//GivePlayerItem(clientIndex, "weapon_decoy");
		//GivePlayerItem(clientIndex, "weapon_flashbang");
		//GivePlayerItem(clientIndex, "weapon_molotov");
		//GivePlayerItem(clientIndex, "weapon_decoy");
		//GivePlayerItem(clientIndex, "weapon_flashbang");
		//GivePlayerItem(clientIndex, "weapon_molotov");
		weaponsGivenThisRound[clientIndex] = true;
		
		GivePlayerItem(clientIndex, "weapon_knife");
		//FakeClientCommand(clientIndex,"use weapon_knife");
		//FakeClientCommand(clientIndex,"sm_menu");
		
		Timers[clientIndex] = CreateTimer(6.0, Fix, clientIndex);
	}
}

stock StripAllWeapons(iClient)
{
    int iEnt;
    for (int i = 0; i <= 4; i++)
    {
        while ((iEnt = GetPlayerWeaponSlot(iClient, i)) != -1)
        {
            RemovePlayerItem(iClient, iEnt);
            AcceptEntityInput(iEnt, "Kill");
        }
    }
}  

public OnClientPutInServer(client)
{
	ResetClientSettings(client);
}

public OnClientCookiesCached(client)
{
	GetClientCookie(client, weapons1, primaryWeapon[client], 24);
	GetClientCookie(client, weapons2, secondaryWeapon[client], 24);
	//rememberChoice[client] = GetCookie(client);
	rememberChoice[client] = false;
}

ResetClientSettings(clientIndex)
{
	weaponsGivenThisRound[clientIndex] = false;
	newWeaponsSelected[clientIndex] = false;
}

public OnClientDisconnect(clientIndex)
{
	DeathTimer(clientIndex);
	
	SetClientCookie(clientIndex, weapons1, primaryWeapon[clientIndex]);
	SetClientCookie(clientIndex, weapons2, secondaryWeapon[clientIndex]);
	
/* 	if(rememberChoice[clientIndex]) SetClientCookie(clientIndex, remember, "On");
	else SetClientCookie(clientIndex, remember, "Off"); */
}

DeathTimer(client)
{
	if (Timers[client] != null)
    {
		KillTimer(Timers[client]);
		Timers[client] = null;
	}
}


ListWeapons()
{
	ClearArray(array_primary);
	ClearArray(array_secondary);
	
	int Items[weapons];
	
	Format(Items[ItemName], 64, "weapon_m4a1");
	Format(Items[desc], 64, "M4A1");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_m4a1_silencer");
	Format(Items[desc], 64, "M4A1-S");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_ak47");
	Format(Items[desc], 64, "AK-47");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_aug");
	Format(Items[desc], 64, "AUG");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_galilar");
	Format(Items[desc], 64, "Galil AR");
	PushArrayArray(array_primary, Items[0]);
	
 	Format(Items[ItemName], 64, "weapon_awp");
	Format(Items[desc], 64, "AWP");
	PushArrayArray(array_primary, Items[0]); 
	
	Format(Items[ItemName], 64, "weapon_sg556");
	Format(Items[desc], 64, "SG 553");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_negev");
	Format(Items[desc], 64, "Negev");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_m249");
	Format(Items[desc], 64, "M249");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_bizon");
	Format(Items[desc], 64, "PP-Bizon");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_p90");
	Format(Items[desc], 64, "P90");
	PushArrayArray(array_primary, Items[0]);
	
 	Format(Items[ItemName], 64, "weapon_scar20");
	Format(Items[desc], 64, "SCAR-20");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_g3sg1");
	Format(Items[desc], 64, "G3SG1");
	PushArrayArray(array_primary, Items[0]); 
	
	Format(Items[ItemName], 64, "weapon_ump45");
	Format(Items[desc], 64, "UMP-45");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_mp7");
	Format(Items[desc], 64, "MP7");
	PushArrayArray(array_primary, Items[0]);

	Format(Items[ItemName], 64, "weapon_famas");
	Format(Items[desc], 64, "FAMAS");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_mp9");
	Format(Items[desc], 64, "MP9");
	PushArrayArray(array_primary, Items[0]);

	Format(Items[ItemName], 64, "weapon_mac10");
	Format(Items[desc], 64, "MAC-10");
	PushArrayArray(array_primary, Items[0]);
	
 	Format(Items[ItemName], 64, "weapon_ssg08");
	Format(Items[desc], 64, "SSG 08");
	PushArrayArray(array_primary, Items[0]); 
	
	Format(Items[ItemName], 64, "weapon_nova");
	Format(Items[desc], 64, "Nova");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_xm1014");
	Format(Items[desc], 64, "XM1014");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_sawedoff");
	Format(Items[desc], 64, "Sawed-Off");
	PushArrayArray(array_primary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_mag7");
	Format(Items[desc], 64, "MAG-7");
	PushArrayArray(array_primary, Items[0]);
	

	
	// Secondary weapons
	
	Format(Items[ItemName], 64, "weapon_deagle");
	Format(Items[desc], 64, "Desert Eagle");
	PushArrayArray(array_secondary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_elite");
	Format(Items[desc], 64, "Dual Berettas");
	PushArrayArray(array_secondary, Items[0]);

	Format(Items[ItemName], 64, "weapon_tec9");
	Format(Items[desc], 64, "Tec-9");
	PushArrayArray(array_secondary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_fiveseven");
	Format(Items[desc], 64, "Five-SeveN");
	PushArrayArray(array_secondary, Items[0]);

 	Format(Items[ItemName], 64, "weapon_cz75a");
	Format(Items[desc], 64, "CZ75-Auto");
	PushArrayArray(array_secondary, Items[0]); 
	
	Format(Items[ItemName], 64, "weapon_glock");
	Format(Items[desc], 64, "Glock-18");
	PushArrayArray(array_secondary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_usp_silencer");
	Format(Items[desc], 64, "USP-S");
	PushArrayArray(array_secondary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_p250");
	Format(Items[desc], 64, "P250");
	PushArrayArray(array_secondary, Items[0]);
	
	Format(Items[ItemName], 64, "weapon_hkp2000");
	Format(Items[desc], 64, "P2000");
	PushArrayArray(array_secondary, Items[0]);
	
}

/* bool:GetCookie(client)
{
	char buffer[10];
	GetClientCookie(client, remember, buffer, sizeof(buffer));
	
	return StrEqual(buffer, "On");
} */