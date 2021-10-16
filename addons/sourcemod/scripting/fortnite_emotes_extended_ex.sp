/*  SM Fortnite Emotes Extended
 *
 *  Copyright (C) 2020 Francisco 'Franc1sco' García
 * 
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT 
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS 
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along with 
 * this program. If not, see http://www.gnu.org/licenses/.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <autoexecconfig>
#undef REQUIRE_PLUGIN
#include <adminmenu>

#pragma newdecls required

ConVar g_cvThirdperson;
ConVar g_cvHidePlayers;

TopMenu hTopMenu;

ConVar g_cvFlagEmotesMenu;
ConVar g_cvFlagDancesMenu;
ConVar g_cvCooldown;
ConVar g_cvBlockRoundStart;
ConVar g_cvSoundVolume;
ConVar g_cvEmotesSounds;
ConVar g_cvHideWeapons;
ConVar g_cvTeleportBack;

int g_iEmoteEnt[MAXPLAYERS+1];
int g_iEmoteSoundEnt[MAXPLAYERS+1];

int g_EmotesTarget[MAXPLAYERS+1];

char g_sEmoteSound[MAXPLAYERS+1][PLATFORM_MAX_PATH];

bool g_bClientDancing[MAXPLAYERS+1];


Handle CooldownTimers[MAXPLAYERS+1];
bool g_bEmoteCooldown[MAXPLAYERS+1];

int g_iWeaponHandEnt[MAXPLAYERS+1];
bool g_bBlockEmote[MAXPLAYERS + 1];

Handle g_EmoteForward;
Handle g_EmoteForward_Pre;
bool g_bHooked[MAXPLAYERS + 1];
Handle g_bHideWeaponsCookie;
bool g_bHideWeapons[MAXPLAYERS+1];

Handle g_hCEconWearable_Equip;

float g_fLastAngles[MAXPLAYERS+1][3];
float g_fLastPosition[MAXPLAYERS+1][3];


public Plugin myinfo =
{
	name = "SM Fortnite Emotes Extended",
	author = "Kodua, Franc1sco franug, TheBO$$",
	description = "This plugin is for demonstration of some animations from Fortnite in CS:GO",
	version = "1.4.2",
	url = "https://github.com/Franc1sco/Fortnite-Emotes-Extended"
};

public void OnPluginStart()
{	
	LoadTranslations("common.phrases");
	LoadTranslations("fnemotes.phrases");
	
	RegConsoleCmd("sm_emotes", Command_Menu);
	RegConsoleCmd("sm_emote", Command_Menu);
	RegConsoleCmd("sm_dances", Command_Menu);	
	RegConsoleCmd("sm_dance", Command_Menu);
	RegAdminCmd("sm_setemotes", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
	RegAdminCmd("sm_setemote", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
	RegAdminCmd("sm_setdances", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
	RegAdminCmd("sm_setdance", Command_Admin_Emotes, ADMFLAG_GENERIC, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");

	HookEvent("player_death", 	Event_PlayerDeath, 	EventHookMode_Pre);

	HookEvent("player_hurt", 	Event_PlayerHurt, 	EventHookMode_Pre);
	
	HookEvent("round_prestart",  Event_Start);
	
	HookEvent("round_end",  Event_RoundEnd);
	
	HookEvent("player_spawned", Event_PlayerSpawn);
	
	HookEvent("round_freeze_end",  Event_FreezeEnd);
	
	/**
		Convars
	**/
	
	AutoExecConfig_SetFile("fortnite_emotes_extended");

	g_cvEmotesSounds = AutoExecConfig_CreateConVar("sm_emotes_sounds", "1", "Enable/Disable sounds for emotes.", _, true, 0.0, true, 1.0);
	g_cvCooldown = AutoExecConfig_CreateConVar("sm_emotes_cooldown", "4.0", "Cooldown for emotes in seconds. -1 or 0 = no cooldown.");
	g_cvSoundVolume = AutoExecConfig_CreateConVar("sm_emotes_soundvolume", "0.4", "Sound volume for the emotes.");
	g_cvFlagEmotesMenu = AutoExecConfig_CreateConVar("sm_emotes_admin_flag_menu", "", "admin flag for emotes (empty for all players)");
	g_cvFlagDancesMenu = AutoExecConfig_CreateConVar("sm_dances_admin_flag_menu", "", "admin flag for dances (empty for all players)");
	g_cvHideWeapons = AutoExecConfig_CreateConVar("sm_emotes_hide_weapons", "1", "Hide weapons when dancing", _, true, 0.0, true, 1.0);
	g_cvHidePlayers = AutoExecConfig_CreateConVar("sm_emotes_hide_enemies", "0", "Hide enemy players when dancing", _, true, 0.0, true, 1.0);
	g_cvTeleportBack = AutoExecConfig_CreateConVar("sm_emotes_teleportonend", "0", "Teleport back to the exact position when he started to dance. (Some maps need this for teleport triggers)", _, true, 0.0, true, 1.0);
	g_cvBlockRoundStart = CreateConVar("sm_emotes_block_round_start", "0", "block dancing during round", _, true, 0.0, true, 1.0);
	
	AutoExecConfig_ExecuteFile();
	
	AutoExecConfig_CleanFile();
	
	/**
		End Convars
	**/

	g_cvThirdperson = FindConVar("sv_allow_thirdperson");
	if (!g_cvThirdperson) SetFailState("sv_allow_thirdperson not found!");

	g_cvThirdperson.AddChangeHook(OnConVarChanged);
	g_cvThirdperson.BoolValue = true;
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}	
	
	g_EmoteForward = CreateGlobalForward("fnemotes_OnEmote", ET_Ignore, Param_Cell);
	g_EmoteForward_Pre = CreateGlobalForward("fnemotes_OnEmote_Pre", ET_Event, Param_Cell);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
            if (IsValidClient(i) && g_bClientDancing[i]) {
				StopEmote(i);
			}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("fnemotes");
	CreateNative("fnemotes_IsClientEmoting", Native_IsClientEmoting);
	return APLRes_Success;
}

void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == g_cvThirdperson)
	{
		if(newValue[0] != '1') convar.BoolValue = true;
	}
}

int Native_IsClientEmoting(Handle plugin, int numParams)
{
	return g_bClientDancing[GetNativeCell(1)];
}

public void OnMapStart()
{
	AddFileToDownloadsTable("models/player/custom_player/kodua/fortnite_emotes_v2.mdl");
	AddFileToDownloadsTable("models/player/custom_player/kodua/fortnite_emotes_v2.vvd");
	AddFileToDownloadsTable("models/player/custom_player/kodua/fortnite_emotes_v2.dx90.vtx");

	// edit
	// add the sound file routes here

	AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_aerobics_01.wav"); 
	AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_music_emotes_bendy.wav");
	AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_breakdance_music.mp3");
	AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_groove_jam_a.wav");
	AddFileToDownloadsTable("sound/kodua/fortnite_emotes/athena_emote_founders_music.wav");
	AddFileToDownloadsTable("sound/kodua/fortnite_emotes/emote_boogiedown.wav");
    

	// this dont touch
	PrecacheModel("models/player/custom_player/kodua/fortnite_emotes_v2.mdl", true);

	// edit
	// add mp3 files without sound/
	// add wav files with */
	
	PrecacheSound("*/kodua/fortnite_emotes/emote_aerobics_01.wav");
	PrecacheSound("*/kodua/fortnite_emotes/athena_music_emotes_bendy.wav");
	PrecacheSound("kodua/fortnite_emotes/athena_emote_breakdance_music.mp3");
	PrecacheSound("*/kodua/fortnite_emotes/emote_groove_jam_a.wav");
	PrecacheSound("*/kodua/fortnite_emotes/athena_emote_founders_music.wav");
	PrecacheSound("*/kodua/fortnite_emotes/emote_boogiedown.wav");
	
}


public void OnClientPutInServer(int client)
{
	if (IsValidClient(client))
	{	
		ResetCam(client);
		TerminateEmote(client);
		g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;

		if (CooldownTimers[client] != null)
		{
			KillTimer(CooldownTimers[client]);
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (IsValidClient(client))
	{
		ResetCam(client);
		TerminateEmote(client);

		if (CooldownTimers[client] != null)
		{
			KillTimer(CooldownTimers[client]);
			CooldownTimers[client] = null;
			g_bEmoteCooldown[client] = false;
		}
	}
	g_bHooked[client] = false;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidClient(client))
	{
		ResetCam(client);
		StopEmote(client);
	}
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) 
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	char sAttacker[16];
	GetEntityClassname(attacker, sAttacker, sizeof(sAttacker));
	if (StrEqual(sAttacker, "worldspawn"))//If player was killed by bomb
	{
		int client = GetClientOfUserId(event.GetInt("userid"));
		StopEmote(client);
	}
}

void Event_Start(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
            if (IsValidClient(i, false) && g_bClientDancing[i]) {
				ResetCam(i);
				//StopEmote(client);
				WeaponUnblock(i);
				
				g_bClientDancing[i] = false;
			}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
        if (IsValidClient(i) && g_bClientDancing[i]) {
			ResetCam(i);
			WeaponUnblock(i);
			g_bClientDancing[i] = false;
		}
		
		g_bBlockEmote[i] = false;
	}
}

void Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
        if (IsValidClient(i) && g_bClientDancing[i]) {
			if(g_cvBlockRoundStart.BoolValue)
			{
				ResetCam(i);
				StopEmote(i);
				WeaponUnblock(i);
				g_bClientDancing[i] = false;
			}
		}
		
		g_bBlockEmote[i] = true;
	}
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));		
	g_bBlockEmote[client] = false;
}

public Action Command_Menu(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;


	char sBuffer[32];
	g_cvFlagEmotesMenu.GetString(sBuffer, sizeof(sBuffer));

	if (CheckAdminFlags(client, ReadFlagString(sBuffer)))
	{
		Menu_Dance(client);
	}
	else CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");	

	return Plugin_Handled;
}

Action CreateEmote(int client, const char[] anim1, const char[] anim2, const char[] soundName, bool isLooped)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	if(g_cvBlockRoundStart.BoolValue)
	{
		if(g_bBlockEmote[client])
		{
			CReplyToCommand(client, "%t", "BLOCK_ON_ROUND_START");
			return Plugin_Handled;
		}
	}		

	if (!IsPlayerAlive(client))
	{
		CReplyToCommand(client, "%t", "MUST_BE_ALIVE");
		return Plugin_Handled;
	}

	if (!(GetEntityFlags(client) & FL_ONGROUND))
	{
		CReplyToCommand(client, "%t", "STAY_ON_GROUND");
		return Plugin_Handled;
	}
	
	if (GetEntProp(client, Prop_Send, "m_bIsScoped"))
	{
		CReplyToCommand(client, "%t", "SCOPE_DETECTED");
		return Plugin_Handled;
	}

	if (CooldownTimers[client])
	{
		CReplyToCommand(client, "%t", "COOLDOWN_EMOTES");
		return Plugin_Handled;
	}

	if (StrEqual(anim1, ""))
	{
		CReplyToCommand(client, "%t", "AMIN_1_INVALID");
		return Plugin_Handled;
	}

	if (g_iEmoteEnt[client])
		StopEmote(client);

	if (GetEntityMoveType(client) == MOVETYPE_NONE)
	{
		CReplyToCommand(client, "%t", "CANNOT_USE_NOW");
		return Plugin_Handled;
	}

	int EmoteEnt = CreateEntityByName("prop_dynamic");
	if (IsValidEntity(EmoteEnt))
	{
		SetEntityMoveType(client, MOVETYPE_NONE);
		WeaponBlock(client);

		float vec[3], ang[3];
		GetClientAbsOrigin(client, vec);
		GetClientAbsAngles(client, ang);
		
		g_fLastPosition[client] = vec;
		g_fLastAngles[client] = ang;

		char emoteEntName[16];
		FormatEx(emoteEntName, sizeof(emoteEntName), "emoteEnt%i", GetRandomInt(1000000, 9999999));
		
		DispatchKeyValue(EmoteEnt, "targetname", emoteEntName);
		DispatchKeyValue(EmoteEnt, "model", "models/player/custom_player/kodua/fortnite_emotes_v2.mdl");
		DispatchKeyValue(EmoteEnt, "solid", "0");
		DispatchKeyValue(EmoteEnt, "rendermode", "10");

		ActivateEntity(EmoteEnt);
		DispatchSpawn(EmoteEnt);

		TeleportEntity(EmoteEnt, vec, ang, NULL_VECTOR);
		
		SetVariantString(emoteEntName);
		AcceptEntityInput(client, "SetParent", client, client, 0);

		g_iEmoteEnt[client] = EntIndexToEntRef(EmoteEnt);

		int enteffects = GetEntProp(client, Prop_Send, "m_fEffects");
		enteffects |= 1; /* This is EF_BONEMERGE */
		enteffects |= 16; /* This is EF_NOSHADOW */
		enteffects |= 64; /* This is EF_NORECEIVESHADOW */
		enteffects |= 128; /* This is EF_BONEMERGE_FASTCULL */
		enteffects |= 512; /* This is EF_PARENT_ANIMATES */
		SetEntProp(client, Prop_Send, "m_fEffects", enteffects);

		//Sound

		if (g_cvEmotesSounds.BoolValue && !StrEqual(soundName, ""))
		{
			int EmoteSoundEnt = CreateEntityByName("info_target");
			if (IsValidEntity(EmoteSoundEnt))
			{
				char soundEntName[16];
				FormatEx(soundEntName, sizeof(soundEntName), "soundEnt%i", GetRandomInt(1000000, 9999999));

				DispatchKeyValue(EmoteSoundEnt, "targetname", soundEntName);

				DispatchSpawn(EmoteSoundEnt);

				vec[2] += 72.0;
				TeleportEntity(EmoteSoundEnt, vec, NULL_VECTOR, NULL_VECTOR);

				SetVariantString(emoteEntName);
				AcceptEntityInput(EmoteSoundEnt, "SetParent");

				g_iEmoteSoundEnt[client] = EntIndexToEntRef(EmoteSoundEnt);

				//Formatting sound path

				char soundNameBuffer[64];

				if (StrEqual(soundName, "ninja_dance_01") || StrEqual(soundName, "dance_soldier_03"))
				{
					int randomSound = GetRandomInt(0, 1);
					if(randomSound)
					{
						soundNameBuffer = "ninja_dance_01";
					} else
					{
						soundNameBuffer = "dance_soldier_03";
					}
				} else
				{
					FormatEx(soundNameBuffer, sizeof(soundNameBuffer), "%s", soundName);
				}

				if (isLooped)
				{
					FormatEx(g_sEmoteSound[client], PLATFORM_MAX_PATH, "*/kodua/fortnite_emotes/%s.wav", soundNameBuffer);
				} else
				{
					FormatEx(g_sEmoteSound[client], PLATFORM_MAX_PATH, "kodua/fortnite_emotes/%s.mp3", soundNameBuffer);
				}

				EmitSoundToAll(g_sEmoteSound[client], EmoteSoundEnt, SNDCHAN_AUTO, SNDLEVEL_CONVO, _, g_cvSoundVolume.FloatValue, _, _, vec, _, _, _);
			}
		} else
		{
			g_sEmoteSound[client] = "";
		}

		if (StrEqual(anim2, "none", false))
		{
			HookSingleEntityOutput(EmoteEnt, "OnAnimationDone", EndAnimation, true);
		} else
		{
			SetVariantString(anim2);
			AcceptEntityInput(EmoteEnt, "SetDefaultAnimation", -1, -1, 0);
		}

		SetVariantString(anim1);
		AcceptEntityInput(EmoteEnt, "SetAnimation", -1, -1, 0);

		SetCam(client);

		g_bClientDancing[client] = true;
		
		if(g_cvHidePlayers.BoolValue)
		{
			for(int i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client) && !g_bHooked[i])
				{
					SDKHook(i, SDKHook_SetTransmit, SetTransmit);
					g_bHooked[i] = true;
				}
		}

		if (g_cvCooldown.FloatValue > 0.0)
		{
			CooldownTimers[client] = CreateTimer(g_cvCooldown.FloatValue, ResetCooldown, client);
		}
		
		if(g_EmoteForward != null)
		{
			Call_StartForward(g_EmoteForward);
			Call_PushCell(client);
			Call_Finish();
		}
	}
	
	return Plugin_Handled;
}

public Action OnPlayerRunCmd(int client, int &iButtons, int &iImpulse, float fVelocity[3], float fAngles[3], int &iWeapon)
{
	if (g_bClientDancing[client] && !(GetEntityFlags(client) & FL_ONGROUND))
		StopEmote(client);

	static int iAllowedButtons = IN_BACK | IN_FORWARD | IN_MOVELEFT | IN_MOVERIGHT | IN_WALK | IN_SPEED | IN_SCORE;

	if (iButtons == 0)
		return Plugin_Continue;

	if (g_iEmoteEnt[client] == 0)
		return Plugin_Continue;

	if ((iButtons & iAllowedButtons) && !(iButtons &~ iAllowedButtons)) 
		return Plugin_Continue;

	StopEmote(client);

	return Plugin_Continue;
}

void EndAnimation(const char[] output, int caller, int activator, float delay) 
{
	if (caller > 0)
	{
		activator = GetEmoteActivator(EntIndexToEntRef(caller));
		StopEmote(activator);
	}
}

int GetEmoteActivator(int iEntRefDancer)
{
	if (iEntRefDancer == INVALID_ENT_REFERENCE)
		return 0;
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (g_iEmoteEnt[i] == iEntRefDancer) 
		{
			return i;
		}
	}
	return 0;
}

void StopEmote(int client)
{
	if (!g_iEmoteEnt[client])
		return;

	int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
	if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt))
	{
		char emoteEntName[50];
		GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
		SetVariantString(emoteEntName);
		AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
		DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
		AcceptEntityInput(iEmoteEnt, "FireUser1");
		
		if(g_cvTeleportBack.BoolValue)
			TeleportEntity(client, g_fLastPosition[client], g_fLastAngles[client], NULL_VECTOR);
		
		ResetCam(client);
		WeaponUnblock(client);
		SetEntityMoveType(client, MOVETYPE_WALK);

		g_iEmoteEnt[client] = 0;
		g_bClientDancing[client] = false;
	} else
	{
		g_iEmoteEnt[client] = 0;
		g_bClientDancing[client] = false;
	}

	if (g_iEmoteSoundEnt[client])
	{
		int iEmoteSoundEnt = EntRefToEntIndex(g_iEmoteSoundEnt[client]);

		if (!StrEqual(g_sEmoteSound[client], "") && iEmoteSoundEnt && iEmoteSoundEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteSoundEnt))
		{
			StopSound(iEmoteSoundEnt, SNDCHAN_AUTO, g_sEmoteSound[client]);
			AcceptEntityInput(iEmoteSoundEnt, "Kill");
			g_iEmoteSoundEnt[client] = 0;
		} else
		{
			g_iEmoteSoundEnt[client] = 0;
		}
	}
}

void TerminateEmote(int client)
{
	if (!g_iEmoteEnt[client])
		return;

	int iEmoteEnt = EntRefToEntIndex(g_iEmoteEnt[client]);
	if (iEmoteEnt && iEmoteEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteEnt))
	{
		char emoteEntName[50];
		GetEntPropString(iEmoteEnt, Prop_Data, "m_iName", emoteEntName, sizeof(emoteEntName));
		SetVariantString(emoteEntName);
		AcceptEntityInput(client, "ClearParent", iEmoteEnt, iEmoteEnt, 0);
		DispatchKeyValue(iEmoteEnt, "OnUser1", "!self,Kill,,1.0,-1");
		AcceptEntityInput(iEmoteEnt, "FireUser1");

		g_iEmoteEnt[client] = 0;
		g_bClientDancing[client] = false;
	} else
	{
		g_iEmoteEnt[client] = 0;
		g_bClientDancing[client] = false;
	}

	if (g_iEmoteSoundEnt[client])
	{
		int iEmoteSoundEnt = EntRefToEntIndex(g_iEmoteSoundEnt[client]);

		if (!StrEqual(g_sEmoteSound[client], "") && iEmoteSoundEnt && iEmoteSoundEnt != INVALID_ENT_REFERENCE && IsValidEntity(iEmoteSoundEnt))
		{
			StopSound(iEmoteSoundEnt, SNDCHAN_AUTO, g_sEmoteSound[client]);
			AcceptEntityInput(iEmoteSoundEnt, "Kill");
			g_iEmoteSoundEnt[client] = 0;
		} else
		{
			g_iEmoteSoundEnt[client] = 0;
		}
	}
}

void WeaponBlock(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
	SDKHook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);
	
	if(g_cvHideWeapons.BoolValue)
		SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
		
	int iEnt = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(iEnt != -1)
	{
		g_iWeaponHandEnt[client] = EntIndexToEntRef(iEnt);
		
		SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", -1);
	}
}

void WeaponUnblock(int client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUseSwitch);
	SDKUnhook(client, SDKHook_WeaponSwitch, WeaponCanUseSwitch);
	
	//Even if are not activated, there will be no errors
	SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	
	if(GetEmotePeople() == 0)
	{
		for(int i = 1; i <= MaxClients; i++)
			if (IsClientInGame(i) && g_bHooked[i])
			{
				SDKUnhook(i, SDKHook_SetTransmit, SetTransmit);
				g_bHooked[i] = false;
			}
	}
	
	if(IsPlayerAlive(client) && g_iWeaponHandEnt[client] != INVALID_ENT_REFERENCE)
	{
		int iEnt = EntRefToEntIndex(g_iWeaponHandEnt[client]);
		if(iEnt != INVALID_ENT_REFERENCE)
		{
			SetEntPropEnt(client, Prop_Send, "m_hActiveWeapon", iEnt);
		}
	}
	
	g_iWeaponHandEnt[client] = INVALID_ENT_REFERENCE;
}

Action WeaponCanUseSwitch(int client, int weapon)
{
	return Plugin_Stop;
}

void OnPostThinkPost(int client)
{
	SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
}

public Action SetTransmit(int entity, int client) 
{ 
	if(g_bClientDancing[client] && IsPlayerAlive(client) && GetClientTeam(client) != GetClientTeam(entity)) return Plugin_Handled;
	
	return Plugin_Continue; 
} 

void SetCam(int client)
{
	ClientCommand(client, "cam_collision 0");
	ClientCommand(client, "cam_idealdist 100");
	ClientCommand(client, "cam_idealpitch 0");
	ClientCommand(client, "cam_idealyaw 0");
	ClientCommand(client, "thirdperson");
}

void ResetCam(int client)
{
	ClientCommand(client, "firstperson");
	ClientCommand(client, "cam_collision 1");
	ClientCommand(client, "cam_idealdist 150");
}

Action ResetCooldown(Handle timer, any client)
{
	CooldownTimers[client] = null;
}

Action Menu_Dance(int client)
{
	Menu menu = new Menu(MenuHandler1);

	char title[65];
	Format(title, sizeof(title), "%T:", "TITLE_MAIM_MENU", client);
	menu.SetTitle(title);	

	//AddTranslatedMenuItem(menu, "", "RANDOM_EMOTE", client);
	//AddTranslatedMenuItem(menu, "", "RANDOM_DANCE", client);
	AddTranslatedMenuItem(menu, "", "EMOTES_LIST", client);
	AddTranslatedMenuItem(menu, "", "DANCES_LIST", client);
	
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 
	return Plugin_Handled;
}

int MenuHandler1(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{		
		case MenuAction_Select:
		{
			int client = param1;
			
			switch (param2)
			{
				//case 0: 
				//{
					//RandomEmote(client);
				//	Menu_Dance(client);
				//}		
				//case 1: 
				//{
					//RandomDance(client);
				//	Menu_Dance(client);
				//}		
				case 0: EmotesMenu(client);
				case 1: DancesMenu(client);	
				
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
}


Action EmotesMenu(int client)
{
	char sBuffer[32];
	g_cvFlagEmotesMenu.GetString(sBuffer, sizeof(sBuffer));

	if (!CheckAdminFlags(client, ReadFlagString(sBuffer)))
	{
		CPrintToChat(client, "%t", "NO_EMOTES_ACCESS_FLAG");
		return Plugin_Handled;
	}
	Menu menu = new Menu(MenuHandlerEmotes);
	
	char title[65];
	Format(title, sizeof(title), "%T:", "TITLE_EMOTES_MENU", client);
	menu.SetTitle(title);	

	AddTranslatedMenuItem(menu, "1", "Emote_Fonzie_Pistol", client);
	AddTranslatedMenuItem(menu, "2", "Emote_Calculated", client);
	AddTranslatedMenuItem(menu, "3", "Emote_Flex", client);	
	AddTranslatedMenuItem(menu, "4", "Emote_HandSignals", client);
	AddTranslatedMenuItem(menu, "5", "Emote_NotToday", client);
	AddTranslatedMenuItem(menu, "6", "Emote_Kung-Fu_Salute", client);

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 
	return Plugin_Handled;
}

int MenuHandlerEmotes(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{		
		case MenuAction_Select:
		{
			char info[16];
			if(menu.GetItem(param2, info, sizeof(info)))
			{
				int iParam2 = StringToInt(info);

				switch (iParam2)
				{
					case 1:
					CreateEmote(client, "Emote_Fonzie_Pistol", "none", "", false);
					case 2:
					CreateEmote(client, "Emote_Calculated", "none", "", false);
					case 3:
					CreateEmote(client, "Emote_Flex", "none", "", false);
					case 4:
					CreateEmote(client, "Emote_HandSignals", "none", "", false);
					case 5:
					CreateEmote(client, "Emote_NotToday", "none", "", false);	
					case 6:
					CreateEmote(client, "Emote_Kung-Fu_Salute", "none", "", false);
					
				}
			}
			menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Dance(client);
			}
		}
	}
}

Action DancesMenu(int client)
{
	char sBuffer[32];
	g_cvFlagDancesMenu.GetString(sBuffer, sizeof(sBuffer));

	if (!CheckAdminFlags(client, ReadFlagString(sBuffer)))
	{
		CPrintToChat(client, "%t", "NO_DANCES_ACCESS_FLAG");
		return Plugin_Handled;
	}
	Menu menu = new Menu(MenuHandlerDances);
	
	char title[65];
	Format(title, sizeof(title), "%T:", "TITLE_DANCES_MENU", client);
	menu.SetTitle(title);	
	
	AddTranslatedMenuItem(menu, "1", "Emote_AerobicChamp", client);
	AddTranslatedMenuItem(menu, "2", "Emote_Bendy", client);
	AddTranslatedMenuItem(menu, "3", "Emote_Boogie_Down_Intro", client);	
	AddTranslatedMenuItem(menu, "4", "Emote_Dance_Breakdance", client);
	AddTranslatedMenuItem(menu, "5", "Emote_GrooveJam", client);	
	AddTranslatedMenuItem(menu, "6", "Emote_TechnoZombie", client);		

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
 
	return Plugin_Handled;
}

int MenuHandlerDances(Menu menu, MenuAction action, int client, int param2)
{
	switch (action)
	{		
		case MenuAction_Select:
		{
			char info[16];
			if(menu.GetItem(param2, info, sizeof(info)))
			{
				int iParam2 = StringToInt(info);

				switch (iParam2)
				{
					case 1:
					CreateEmote(client, "Emote_AerobicChamp", "none", "emote_aerobics_01", true);
					case 2:
					CreateEmote(client, "Emote_Bendy", "none", "athena_music_emotes_bendy", true);
					case 3:
					CreateEmote(client, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", "emote_boogiedown", true);	
					case 4:
					CreateEmote(client, "Emote_Dance_Breakdance", "none", "athena_emote_breakdance_music", false);
					case 5:
					CreateEmote(client, "Emote_GrooveJam", "none", "emote_groove_jam_a", true);	
					case 6:
					CreateEmote(client, "Emote_TechnoZombie", "none", "athena_emote_founders_music", true);			
				}
			}
			menu.DisplayAt(client, GetMenuSelectionPosition(), MENU_TIME_FOREVER);
		}
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				Menu_Dance(client);
			}
		}
	}
}

Action RandomEmote(int i)
{
					char sBuffer[32];
					g_cvFlagEmotesMenu.GetString(sBuffer, sizeof(sBuffer));

					if (!CheckAdminFlags(i, ReadFlagString(sBuffer)))
					{
						CPrintToChat(i, "%t", "NO_EMOTES_ACCESS_FLAG");
						return;
					}
					
					int number = GetRandomInt(1, 36);
					
					switch (number)
					{
						case 1:
						CreateEmote(i, "Emote_Fonzie_Pistol", "none", "", false);
						case 2:
						CreateEmote(i, "Emote_Calculated", "none", "", false);
						case 3:
						CreateEmote(i, "Emote_Flex", "none", "", false);
						case 4:
						CreateEmote(i, "Emote_HandSignals", "none", "", false);
						case 5:
						CreateEmote(i, "Emote_NotToday", "none", "", false);
						case 6:
						CreateEmote(i, "Emote_Kung-Fu_Salute", "none", "", false);
					}	

}

Action RandomDance(int i)
{
					char sBuffer[32];
					g_cvFlagDancesMenu.GetString(sBuffer, sizeof(sBuffer));

					if (!CheckAdminFlags(i, ReadFlagString(sBuffer)))
					{
						CPrintToChat(i, "%t", "NO_DANCES_ACCESS_FLAG");
						return;
					}
					int number = GetRandomInt(1, 48);
					
					switch (number)
					{
						case 1:
						CreateEmote(i, "Emote_AerobicChamp", "none", "emote_aerobics_01", true);
						case 2:
						CreateEmote(i, "Emote_Bendy", "none", "athena_music_emotes_bendy", true);	
						case 3:
						CreateEmote(i, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", "emote_boogiedown", true);	
						case 4:
						CreateEmote(i, "Emote_Dance_Breakdance", "none", "athena_emote_breakdance_music", false);
						case 5:
						CreateEmote(i, "Emote_GrooveJam", "none", "emote_groove_jam_a", true);	
						case 6:
						CreateEmote(i, "Emote_TechnoZombie", "none", "athena_emote_founders_music", true);		
					}	
}


Action Command_Admin_Emotes(int client, int args)
{
	if (args < 1)
	{
		CReplyToCommand(client, "[SM] Usage: sm_setemotes <#userid|name> [Emote ID]");
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	int amount=1;
	if (args > 1)
	{
		char arg2[3];
		GetCmdArg(2, arg2, sizeof(arg2));
		if (StringToIntEx(arg2, amount) < 1 || StringToIntEx(arg2, amount) > 86)
		{
			CReplyToCommand(client, "%t", "INVALID_EMOTE_ID");
			return Plugin_Handled;
		}
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	
	for (int i = 0; i < target_count; i++)
	{
		PerformEmote(client, target_list[i], amount);
	}	
	
	return Plugin_Handled;
}

void PerformEmote(int client, int target, int amount)
{
		switch (amount)
		{
					case 1:
					CreateEmote(target, "Emote_Fonzie_Pistol", "none", "", false);
					case 7:
					CreateEmote(target, "Emote_Calculated", "none", "", false);
					case 15:
					CreateEmote(target, "Emote_Flex", "none", "", false);
					case 17:
					CreateEmote(target, "Emote_HandSignals", "none", "", false);
					case 22:
					CreateEmote(target, "Emote_Kung-Fu_Salute", "none", "", false);
					case 26:
					CreateEmote(target, "Emote_NotToday", "none", "", false);	
					case 41:
					CreateEmote(target, "Emote_AerobicChamp", "none", "emote_aerobics_01", true);
					case 42:
					CreateEmote(target, "Emote_Bendy", "none", "athena_music_emotes_bendy", true);
					case 44:
					CreateEmote(target, "Emote_Boogie_Down_Intro", "Emote_Boogie_Down", "emote_boogiedown", true);	
					case 55:
					CreateEmote(target, "Emote_Dance_Breakdance", "none", "athena_emote_breakdance_music", false);
					case 64:
					CreateEmote(target, "Emote_GrooveJam", "none", "emote_groove_jam_a", true);	
					case 80:
					CreateEmote(target, "Emote_TechnoZombie", "none", "athena_emote_founders_music", true);		
					
					default:
					CPrintToChat(client, "%t", "INVALID_EMOTE_ID");
		}
}

void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);

	/* Block us from being called twice */
	if (topmenu == hTopMenu)
	{
		return;
	}
	
	/* Save the Handle */
	hTopMenu = topmenu;
	
	/* Find the "Player Commands" category */
	TopMenuObject player_commands = hTopMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);

	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		hTopMenu.AddItem("sm_setemotes", AdminMenu_Emotes, player_commands, "sm_setemotes", ADMFLAG_SLAY);
	}
}

void AdminMenu_Emotes(TopMenu topmenu, 
					  TopMenuAction action,
					  TopMenuObject object_id,
					  int param,
					  char[] buffer,
					  int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		Format(buffer, maxlength, "%T", "EMOTE_PLAYER", param);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		DisplayEmotePlayersMenu(param);
	}
}

void DisplayEmotePlayersMenu(int client)
{
	Menu menu = new Menu(MenuHandler_EmotePlayers);
	
	char title[65];
	Format(title, sizeof(title), "%T:", "EMOTE_PLAYER", client);
	menu.SetTitle(title);
	menu.ExitBackButton = true;
	
	AddTargetsToMenu(menu, client, true, true);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_EmotePlayers(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info));
		userid = StringToInt(info);

		if ((target = GetClientOfUserId(userid)) == 0)
		{
			CPrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			CPrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			g_EmotesTarget[param1] = userid;
			DisplayEmotesAmountMenu(param1);
			return;	// Return, because we went to a new menu and don't want the re-draw to occur.
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayEmotePlayersMenu(param1);
		}
	}
	
	return;
}

void DisplayEmotesAmountMenu(int client)
{
	Menu menu = new Menu(MenuHandler_EmotesAmount);
	
	char title[65];
	Format(title, sizeof(title), "%T: %N", "SELECT_EMOTE", client, GetClientOfUserId(g_EmotesTarget[client]));
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	AddTranslatedMenuItem(menu, "1", "Emote_Fonzie_Pistol", client);
	AddTranslatedMenuItem(menu, "7", "Emote_Calculated", client);
	AddTranslatedMenuItem(menu, "15", "Emote_Flex", client);	
	AddTranslatedMenuItem(menu, "17", "Emote_HandSignals", client);
	AddTranslatedMenuItem(menu, "22", "Emote_Kung-Fu_Salute", client);
	AddTranslatedMenuItem(menu, "26", "Emote_NotToday", client);
	AddTranslatedMenuItem(menu, "41", "Emote_AerobicChamp", client);
	AddTranslatedMenuItem(menu, "42", "Emote_Bendy", client);
	AddTranslatedMenuItem(menu, "44", "Emote_Boogie_Down_Intro", client);	
	AddTranslatedMenuItem(menu, "55", "Emote_Dance_Breakdance", client);
	AddTranslatedMenuItem(menu, "64", "Emote_GrooveJam", client);	
	AddTranslatedMenuItem(menu, "80", "Emote_TechnoZombie", client);
	
	
	menu.Display(client, MENU_TIME_FOREVER);
}

int MenuHandler_EmotesAmount(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hTopMenu)
		{
			hTopMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32];
		int amount;
		int target;
		
		menu.GetItem(param2, info, sizeof(info));
		amount = StringToInt(info);

		if ((target = GetClientOfUserId(g_EmotesTarget[param1])) == 0)
		{
			CPrintToChat(param1, "[SM] %t", "Player no longer available");
		}
		else if (!CanUserTarget(param1, target))
		{
			CPrintToChat(param1, "[SM] %t", "Unable to target");
		}
		else
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(target, name, sizeof(name));
			
			PerformEmote(param1, target, amount);
		}
		
		/* Re-draw the menu if they're still valid */
		if (IsClientInGame(param1) && !IsClientInKickQueue(param1))
		{
			DisplayEmotePlayersMenu(param1);
		}
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrEqual(classname, "trigger_multiple"))
    {
        SDKHook(entity, SDKHook_StartTouch, OnTrigger);
        SDKHook(entity, SDKHook_EndTouch, OnTrigger);
        SDKHook(entity, SDKHook_Touch, OnTrigger);
    }
    else if(StrEqual(classname, "trigger_hurt"))
    {
        SDKHook(entity, SDKHook_StartTouch, OnTrigger);
        SDKHook(entity, SDKHook_EndTouch, OnTrigger);
        SDKHook(entity, SDKHook_Touch, OnTrigger);
    }
    else if(StrEqual(classname, "trigger_push"))
    {
        SDKHook(entity, SDKHook_StartTouch, OnTrigger);
        SDKHook(entity, SDKHook_EndTouch, OnTrigger);
        SDKHook(entity, SDKHook_Touch, OnTrigger);
    }
}

public Action OnTrigger(int entity, int other)
{
    if (0 < other <= MaxClients)
    {
        StopEmote(other);
    }
    return Plugin_Continue;
} 

void AddTranslatedMenuItem(Menu menu, const char[] opt, const char[] phrase, int client)
{
	char buffer[128];
	Format(buffer, sizeof(buffer), "%T", phrase, client);
	menu.AddItem(opt, buffer);
}

stock bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

bool CheckAdminFlags(int client, int iFlag)
{
	int iUserFlags = GetUserFlagBits(client);
	return (iUserFlags & ADMFLAG_ROOT || (iUserFlags & iFlag) == iFlag);
}

int GetEmotePeople()
{
	int count;
	for(int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && g_bClientDancing[i])
			count++;
			
	return count;
}
