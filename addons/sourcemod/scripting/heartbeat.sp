/**
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * 
 * (Это свободная программа: вы можете перераспространять ее и/или изменять
 * ее на условиях Стандартной общественной лицензии GNU в том виде, в каком
 * она была опубликована Фондом свободного программного обеспечения; либо
 * версии 3 лицензии, либо (по вашему выбору) любой более поздней версии.
 * 
 * Эта программа распространяется в надежде, что она будет полезной,
 * но БЕЗО ВСЯКИХ ГАРАНТИЙ; даже без неявной гарантии ТОВАРНОГО ВИДА
 * или ПРИГОДНОСТИ ДЛЯ ОПРЕДЕЛЕННЫХ ЦЕЛЕЙ. Подробнее см. в Стандартной
 * общественной лицензии GNU.
 * 
 * Вы должны были получить копию Стандартной общественной лицензии GNU
 * вместе с этой программой. Если это не так, см.
 * <http://www.gnu.org/licenses/>.)
 */

#pragma semicolon 1
//-------------------------------------------------------------------------------------
// INCLUDES
//-------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>

#include <emitsoundany>

//-------------------------------------------------------------------------------------
// DEFINES
//-------------------------------------------------------------------------------------
#define PLUGIN_VERSION "1.1"

//-------------------------------------------------------------------------------------
// CONSOLE VARIABLES
//-------------------------------------------------------------------------------------
new Handle:		g_hConVar_iHealthBorder			= INVALID_HANDLE;
new Handle:		g_hConVar_szHeartbeatSound		= INVALID_HANDLE;
new Handle:		g_hConVar_fHeartbeatDelay		= INVALID_HANDLE;

new Handle:		g_hConVar_iShakeBorder			= INVALID_HANDLE;
new Handle:		g_hConVar_fShakeAmp				= INVALID_HANDLE;
new Handle:		g_hConVar_fShakeTime			= INVALID_HANDLE;


//-------------------------------------------------------------------------------------
// SHADOW CONSOLE VARIABLES
//-------------------------------------------------------------------------------------
new				g_iHealthBorder;
new	String:		g_szHeartbeatSound[256];
new Float:		g_fHeartbeatDelay;

new 			g_iShakeBorder;
new Float:		g_fShakeAmp;
new Float:		g_fShakeTime;

//-------------------------------------------------------------------------------------
// VARIABLES
//-------------------------------------------------------------------------------------
new Handle:		g_hHeartbeatTimer[MAXPLAYERS+1];
new bool:		g_bRoundNotEnded;

//-------------------------------------------------------------------------------------
// PLUGIN INFO
//-------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "[ HeartBeat ]",
	author = "Regent",
	description = "<- sound of heartbeat ->",
	version = PLUGIN_VERSION,
	url = ""
};

//-------------------------------------------------------------------------------------
// FORWARDS
//-------------------------------------------------------------------------------------
public OnPluginStart()
{
	g_hConVar_iHealthBorder 	= CreateConVar("sm_heartbeat_healthborder", "40", 							"health, at which client will hear sound of heartbeat");
	g_hConVar_szHeartbeatSound 	= CreateConVar("sm_heartbeat_sound", 		"heartbeat/heartbeat_cut.mp3", 	"sound of heartbeat (root folder sound/)");
	g_hConVar_fHeartbeatDelay 	= CreateConVar("sm_heartbeat_delay", 		"1.0", 							"duration of one heartbeat");
	
	g_hConVar_iShakeBorder		= CreateConVar("sm_heartbeat_shakeborder", 	"15", 							"health, at which client start shaking");
	g_hConVar_fShakeAmp			= CreateConVar("sm_heartbeat_shakeamp", 	"10.0", 						"amplitude of shaking");
	g_hConVar_fShakeTime		= CreateConVar("sm_heartbeat_shaketime", 	"1.0", 							"duration of one heartbeat shake");
	
	HookConVarChange(g_hConVar_iHealthBorder, 		ConVar_Callback);
	HookConVarChange(g_hConVar_szHeartbeatSound, 	ConVar_Callback);
	HookConVarChange(g_hConVar_fHeartbeatDelay, 	ConVar_Callback);
	
	HookConVarChange(g_hConVar_iShakeBorder, 		ConVar_Callback);
	HookConVarChange(g_hConVar_fShakeAmp, 			ConVar_Callback);
	HookConVarChange(g_hConVar_fShakeTime, 			ConVar_Callback);
	
	g_iHealthBorder 	= GetConVarInt(g_hConVar_iHealthBorder);
	GetConVarString(g_hConVar_szHeartbeatSound, g_szHeartbeatSound, sizeof(g_szHeartbeatSound) - 1);
	g_fHeartbeatDelay	= GetConVarFloat(g_hConVar_fHeartbeatDelay);
	
	g_iShakeBorder		= GetConVarInt(g_hConVar_iShakeBorder);
	g_fShakeAmp			= GetConVarFloat(g_hConVar_fShakeAmp);
	g_fShakeTime		= GetConVarFloat(g_hConVar_fShakeTime);
	
	HookEvent("player_hurt", 	Event_PlayerHurt);
	HookEvent("round_start", 	Event_RoundStart);
	HookEvent("round_end", 		Event_RoundEnd);
}
public OnMapStart()
{
	decl String:szPath[256];
	Format(szPath, sizeof(szPath), "sound/%s", g_szHeartbeatSound);
	AddFileToDownloadsTable(szPath);
	PrecacheSoundAny(g_szHeartbeatSound);
}

public ConVar_Callback(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	if ( cvar == g_hConVar_iHealthBorder )
	{
		g_iHealthBorder = GetConVarInt(g_hConVar_iHealthBorder);
	}
	else if ( cvar == g_hConVar_szHeartbeatSound )
	{
		GetConVarString(g_hConVar_szHeartbeatSound, g_szHeartbeatSound, sizeof(g_szHeartbeatSound) - 1);
	}
	else if ( cvar == g_hConVar_fHeartbeatDelay )
	{
		g_fHeartbeatDelay = GetConVarFloat(g_hConVar_fHeartbeatDelay);
	}
	else if ( cvar == g_hConVar_iShakeBorder )
	{
		g_iShakeBorder = GetConVarInt(g_hConVar_iShakeBorder);
	}
	else if ( cvar == g_hConVar_fShakeAmp )
	{
		g_fShakeAmp = GetConVarFloat(g_hConVar_fShakeAmp);
	}
	else if ( cvar == g_hConVar_fShakeTime )
	{
		g_fShakeTime = GetConVarFloat(g_hConVar_fShakeTime);
	}
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new iHealth = GetEventInt(event, "health");
	if ( iHealth <= g_iHealthBorder )
	{
		if ( g_bRoundNotEnded )
		{
			new iClient = GetClientOfUserId(GetEventInt(event, "userid"));
			if ( IsPlayerAlive(iClient) && g_hHeartbeatTimer[iClient] == INVALID_HANDLE )
			{
				g_hHeartbeatTimer[iClient] = CreateTimer(g_fHeartbeatDelay, THeartBeat_Callback, GetClientUserId(iClient), TIMER_REPEAT);
				TriggerTimer(g_hHeartbeatTimer[iClient]);
			}
		}
	}
}

public Action:THeartBeat_Callback(Handle:hTimer, any:iUserId)
{
	new iClient = GetClientOfUserId(iUserId);
	if ( iClient < 1 || !IsClientInGame(iClient) || !g_bRoundNotEnded || !IsPlayerAlive(iClient) )
	{
		g_hHeartbeatTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	new iHealth = GetEntProp(iClient, Prop_Send, "m_iHealth");
	if ( iHealth <= g_iHealthBorder )
	{
		EmitSoundToClientAny(iClient, g_szHeartbeatSound);
	}
	else
	{
		g_hHeartbeatTimer[iClient] = INVALID_HANDLE;
		return Plugin_Stop;
	}
	
	if ( iHealth <= g_iShakeBorder )
	{
		new Handle:hMsg = StartMessageOne("Shake", iClient);
		if (hMsg != INVALID_HANDLE && GetUserMessageType() == UM_Protobuf) {
			PbSetInt(hMsg, "command", 0);
			PbSetFloat(hMsg, "local_amplitude", g_fShakeAmp);
			PbSetFloat(hMsg, "frequency", 1.0);
			PbSetFloat(hMsg, "duration", g_fShakeTime);
			EndMessage();
		}
		else {
			BfWriteByte(hMsg,  0);
			BfWriteFloat(hMsg, g_fShakeAmp);
			BfWriteFloat(hMsg, 1.0);
			BfWriteFloat(hMsg, g_fShakeTime);
			EndMessage();
		}
	}
	
	return Plugin_Continue;
}

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundNotEnded = true;
}
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	g_bRoundNotEnded = false;
}
