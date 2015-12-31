/*
 * When the bomb is planted it will be attached to the player that planted the bomb.
 * Convar Notes:
Distance away from the center of the bombsite A, 0 for only on site
Distance away from the center of the bombsite B, -1 to disable check

Player Leaves bomb site radius:
	0- Do nothing. (will still keep the bomb planted on the clients back
	1- Unplant bomb, and give it back to the client
	2- Drop the planted bomb (teleports to the client's feet)
	3- Drop physic bomb
	4- Teleport bomb where it was first planted
	
Player leaves the site, should it try and find a player that is still on site?
	
Droppable bomb: Allows the carrier to be able to drop the bomb.
	1- The bomb will be able to be dropped as a physics item
	2- Additional option to keep the bomb upright
	
Pickup Bomb:
	1- Allows the user to be able to pick up the bomb if it's on the ground.
	
Please note that the unplant bomb feature is not natural, and expect glitches.


SetEntProp(plantedC4, Prop_Send, "m_bBombTicking", false);
SetEntPropFloat(plantedC4, Prop_Send, "m_flTimerLength", );
AcceptEntityInput(plantedC4, "Kill");
GameRules_SetProp("m_bBombPlanted", false, _, _, true);

 */
#pragma semicolon 1
#include <sdktools>
#include <sdkhooks>
#define PLUGIN_VERSION "1.0.0"
int plyCarryingC4;
bool c4Planted = false;
int plantedC4;
int secondaryC4;
int c4weapon;

float emptyVector[3];

// ConVars
//ConVar cDistanceFromSiteA;
//ConVar cDistanceFromSiteB;
//ConVar cPlayerLeaveSite;
//ConVar cPlayerLeaveSiteReplace; //gives bomb to another client.
ConVar cBombEntity;
ConVar cDroppableBomb;
ConVar cPickupBomb;

public Plugin myinfo = {
	name = "Carry C4",
	author = "Mitch.",
	description = "Suicide Bombers",
	version = PLUGIN_VERSION,
	url = "http://dizzle.wtf/"
};

public void OnPluginStart() {
	CreateConVar("sm_carryc4_version", PLUGIN_VERSION, "Carry C4 Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	HookEvent("bomb_planted", Event_BombPlanted);
	HookEvent("round_end", Event_RoundEnd);

	//cDistanceFromSiteA = CreateConVar("sm_carryc4_dist_a", "-1.0", "Distance away from the A site", FCVAR_NONE, true, -1.0, false, 0.0);
	//cDistanceFromSiteB = CreateConVar("sm_carryc4_dist_b", "-1.0", "Distance away from the B site", FCVAR_NONE, true, -1.0, false, 0.0);
	//cPlayerLeaveSite = CreateConVar("sm_carryc4_leavesite", "0", "Option for when the player leaves the site");
	//cPlayerLeaveSiteReplace = CreateConVar("sm_carryc4_leavesite_replace", "0", "Try to give bomb to another player?");
	cBombEntity = CreateConVar("sm_carryc4_c4entity", "1", "Allow the player to physically hold a c4");
	cDroppableBomb = CreateConVar("sm_carryc4_droppable", "1", "Allow the player to drop the bomb");
	cPickupBomb = CreateConVar("sm_carryc4_pickup", "1", "Allow the player to pickup the bomb after it was dropped.");
	AutoExecConfig();

	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

public void OnClientPutInServer(int client) {
	SDKHook(client, SDKHook_WeaponSwitch, OnWeaponSwitch);
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponEquip, OnWeaponEquip);
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);
}

public Action OnWeaponCanUse(int client, int weapon) {
	if(!client || !c4Planted) return Plugin_Continue;
	if(weapon == EntRefToEntIndex(c4weapon)) {
		if(cPickupBomb.IntValue == 0) {
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action OnWeaponSwitch(int client, int weapon) {
	if(!client || !c4Planted) return Plugin_Continue;
	int c4client = GetClientOfUserId(plyCarryingC4);
	if(client != c4client) return Plugin_Continue;
	if(!IsValidEntity(plantedC4)) return Plugin_Continue;
	if(weapon == EntRefToEntIndex(c4weapon)) {
		AcceptEntityInput(plantedC4, "ClearParent");
		parentEntity(plantedC4, client, "legacy_weapon_bone");
		float pos[3], ang[3];
		pos[0] = 1.2;
		pos[1] = -3.0;
		pos[2] = -0.5;
		ang[0] = 0.0;
		ang[1] = 95.0;
		ang[2] = 155.0;
		TeleportEntity(plantedC4, pos, ang, NULL_VECTOR);
		SetEntityRenderColor(weapon, 255, 255, 255, 0);
		SetEntityRenderMode(weapon, RENDER_NONE);
	} else {
		AcceptEntityInput(plantedC4, "ClearParent");
		parentEntity(plantedC4, client, "c4");
		float pos[3];
		pos[2] = -2.0;
		TeleportEntity(plantedC4, pos, NULL_VECTOR, NULL_VECTOR);
	}
	return Plugin_Continue;
}

public Action OnWeaponEquip(int client, int weapon) {
	if(!client || !c4Planted) return Plugin_Continue;
	if(weapon == EntRefToEntIndex(c4weapon)) {
		plyCarryingC4 = GetClientUserId(client);
		AcceptEntityInput(plantedC4, "ClearParent");
		parentEntity(plantedC4, client, "c4");
		float pos[3];
		pos[2] = -2.0;
		TeleportEntity(plantedC4, pos, NULL_VECTOR, NULL_VECTOR);
		SetEntityRenderMode(weapon, RENDER_NONE);
		float fPos[3];
		GetClientAbsOrigin(client, fPos);
		TeleportEntity(secondaryC4, fPos, emptyVector, NULL_VECTOR);
		parentEntity(secondaryC4, client, "");
	}
	return Plugin_Continue;
}

public Action OnWeaponDrop(int client, int weapon) {
	if(!client || !c4Planted) return Plugin_Continue;
	if(weapon == EntRefToEntIndex(c4weapon)) {
		if(cDroppableBomb.IntValue > 0) {
			plyCarryingC4 = -1;
			AcceptEntityInput(plantedC4, "ClearParent");
			AcceptEntityInput(secondaryC4, "ClearParent");
			SetEntityRenderMode(weapon, RENDER_NONE);
			parentEntity(plantedC4, c4weapon, "");
			TeleportEntity(plantedC4, emptyVector, emptyVector, NULL_VECTOR);
		} else {
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public OnPostThinkPost(client) {
	if(!client || !c4Planted) return;
	int c4client = GetClientOfUserId(plyCarryingC4);
	if(client != c4client) return;
	if(!IsValidEntity(plantedC4)) return;
	//Remove the c4 from the player's back.
	SetEntProp(client, Prop_Send, "m_iAddonBits", GetEntProp(client, Prop_Send, "m_iAddonBits") & ~(1<<4));
}

public Action Event_BombPlanted(Event event, const char[] name, bool dontBroadcast) {
	c4Planted = true;
	int c4 = -1;
	c4 = FindEntityByClassname(c4, "planted_c4");
	if(IsValidEntity(c4)) {
		plyCarryingC4 = GetEventInt(event, "userid");
		int player = GetClientOfUserId(plyCarryingC4);
		if(player > 0) {
			//This c4 is used for the client that is holding the bomb to be able to hear the beeps.
			//This will also unparent and kill itself before explosion
			int c42 = CreateEntityByName("planted_c4");
			float bombTime = GetEntPropFloat(c4, Prop_Send, "m_flTimerLength");
			SetEntProp(c42, Prop_Send, "m_bBombTicking", true);
			SetEntPropFloat(c42, Prop_Send, "m_flTimerLength", bombTime);
			SetEntPropFloat(c42, Prop_Send, "m_flC4Blow", GetEntPropFloat(c4, Prop_Send, "m_flC4Blow"));
			DispatchSpawn(c42);
			ActivateEntity(c42);
			char g_sOutput[32];
			Format(g_sOutput, sizeof(g_sOutput), "OnUser1 !self:ClearParent::%f:1", bombTime - 0.3);
			Format(g_sOutput, sizeof(g_sOutput), "OnUser2 !self:Kill::%f:1", bombTime - 0.2);
			SetVariantString(g_sOutput);
			AcceptEntityInput(c42, "AddOutput");
			AcceptEntityInput(c42, "FireUser1");
			AcceptEntityInput(c42, "FireUser2");
			SetEntityRenderMode(c42, RENDER_NONE);
			secondaryC4 = EntIndexToEntRef(c42);
			SDKHook(c42, SDKHook_SetTransmit, OnShouldDisplay);
			//End of second c4.

			plantedC4 = EntIndexToEntRef(c4);
			SDKHook(c4, SDKHook_SetTransmit, OnShouldDisplay);
			if(cBombEntity.IntValue > 0) {
				//Some how doesn't register as an actual C4.
				// naturally disabling planting.
				int c4wep = CreateEntityByName("weapon_c4"); 
				DispatchSpawn(c4wep);
				SetEntityRenderMode(c4wep, RENDER_NONE);
				c4weapon = EntIndexToEntRef(c4wep);
				EquipPlayerWeapon(player, c4wep);
			}
		}
	}
}

public Action:OnShouldDisplay(ent, client) {
	if(!c4Planted) return Plugin_Continue;
	int c4client = GetClientOfUserId(plyCarryingC4);
	if(client != c4client && ent == EntRefToEntIndex(plantedC4)) return Plugin_Continue;
	if(client == c4client && ent == EntRefToEntIndex(secondaryC4)) return Plugin_Continue;
	return Plugin_Handled;
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	c4Planted = false;
	c4weapon = -1;
	plantedC4 = -1;
	secondaryC4 = -1;
}

public void parentEntity(int child, int parent, const char[] attachment) {
	SetVariantString("!activator");
	AcceptEntityInput(child, "SetParent", parent, child, 0);
	if(!StrEqual(attachment, "", false)) {
		SetVariantString(attachment);
		AcceptEntityInput(child, "SetParentAttachment", child, child, 0);
	}
}