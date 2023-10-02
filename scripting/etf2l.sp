#pragma semicolon 1

#include <sourcemod>
#include <SteamWorks>
#include <morecolors>

#pragma newdecls required
#pragma dynamic 131072

public Plugin myinfo = 
{
	name = "", 
	author = "", 
	description = "", 
	version = "", 
	url = ""
};

#include "etf2l/config.sp"
Config g_Config = null;

#include "etf2l/cache.sp"
Cache g_Cache = null;

#include "etf2l/menus.sp"

public void OnPluginStart()
{
	g_Config = new Config();
	g_Cache = new Cache();
	
	char szPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szPath, sizeof(szPath), "data/etf2l/");
	if (!DirExists(szPath))
		CreateDirectory(szPath, 511);
	
	RegConsoleCmd("sm_div", Cmd_Div);
	RegConsoleCmd("sm_divm", Cmd_Divm);
	
	for (int client = 1; client <= MaxClients; ++client)
	{
		if(!IsClientInGame(client) || IsFakeClient(client) || !IsClientAuthorized(client))
			continue;
		
		CheckClientData(client);
	}
}

public Action Cmd_Div(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] Ingame only");
		return Plugin_Handled;
	}
	
	switch(args)
	{
		case 0:
		{
			char szMsg[253];
			for (int target = 1; target <= MaxClients; ++target)
			{
				if(!IsClientInGame(target) || IsFakeClient(target) || 
					!g_Cache.GetAnnonceMsg(target, szMsg, sizeof(szMsg)))
					continue;
				
				CPrintToChatEx(client, target, szMsg);
			}
		}
		
		case 1:
		{
			char szTarget[32];
			GetCmdArg(1, szTarget, sizeof(szTarget));
			
			char szTargetName[MAX_TARGET_LENGTH];
			int target_list[MAXPLAYERS], target_count;
			bool bTargetTranslate;
			
			if((target_count = ProcessTargetString(szTarget, client, target_list, MAXPLAYERS, 
				COMMAND_FILTER_CONNECTED | COMMAND_FILTER_NO_BOTS, szTargetName, sizeof(szTargetName), bTargetTranslate)) <= 0)
			{
				return Plugin_Handled;
			}
			
			char szMsg[253];
			for (int i = 0; i < target_count; ++i)
			{
				int target = target_list[i];
				if(!IsClientInGame(target) || IsFakeClient(target) ||
					!g_Cache.GetAnnonceMsg(target, szMsg, sizeof(szMsg)))
					continue;
				
				CPrintToChatEx(client, target, szMsg);
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Cmd_Divm(int client, int args)
{
	if(!client)
	{
		ReplyToCommand(client, "[SM] Ingame only");
		return Plugin_Handled;
	}
	
	DisplayDivMenu(client);
	
	return Plugin_Handled;
}

public void OnMapEnd()
{
	g_Cache.ClearCache();
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
	
	CheckClientData(client);
}

public void OnClientDisconnect(int client)
{
	g_Cache.Remove(client);
}

void CheckClientData(int client)
{
	char szAuth[32];
	GetClientAuthId(client, AuthId_SteamID64, szAuth, sizeof(szAuth));
	
	char szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "data/etf2l/%s.vdf", szAuth);
	
	int max_age = g_Config.MaxAge;
	
	if(FileExists(szBuffer) && max_age && 
		GetTime() - GetFileTime(szBuffer, FileTime_LastChange) < max_age)
	{
		KeyValues kv = new KeyValues("response");
		if(!kv.ImportFromFile(szBuffer))
		{
			LogError("Error reading cache file '%s'", szBuffer);
		}
		else
		{
			g_Cache.Add(client, kv);
		}
		
		kv.Close();
		
		if(g_Config.Announce)
			AnnoncePlayerToAll(client);
	}
	else
	{
		Format(szBuffer, sizeof(szBuffer), "https://api.etf2l.org/player/%s/full.vdf", szAuth);
		
		Handle hRequest = SteamWorks_CreateHTTPRequest(k_EHTTPMethodGET, szBuffer);
		if(hRequest == null)
		{
			LogError("Error creating http request.");
			return;
		}
		
		DataPack pack = new DataPack();
		pack.WriteString(szAuth);
		pack.WriteCell(GetClientUserId(client));
		
		SteamWorks_SetHTTPRequestContextValue(hRequest, pack);
		SteamWorks_SetHTTPCallbacks(hRequest, OnRequestComplete);
		SteamWorks_SendHTTPRequest(hRequest);
	}
}

public void OnRequestComplete(Handle hRequest, bool bFailure, bool bRequestSuccessful, EHTTPStatusCode eStatusCode, DataPack pack)
{
	if(!bFailure && bRequestSuccessful)
	{
		switch(eStatusCode)
		{
			case k_EHTTPStatusCode200OK:
			{
				SteamWorks_GetHTTPResponseBodyCallback(hRequest, OnResponseBody, pack);
			}
			
			default:
			{
				pack.Position = view_as<DataPackPos>(1);
				int client = GetClientOfUserId(pack.ReadCell());
				pack.Close();
				
				if(client && g_Config.Announce)
					AnnoncePlayerToAll(client);
			}
		}
	}
	else
	{
		pack.Close();
	}
	
	hRequest.Close();
}

public void OnResponseBody(const char[] data, DataPack pack)
{
	char szAuth[32];
	
	pack.Reset();
	pack.ReadString(szAuth, sizeof(szAuth));
	int client = GetClientOfUserId(pack.ReadCell());
	pack.Close();
	
	KeyValues kv = new KeyValues("response");
	if(!kv.ImportFromString(data))
	{
		LogError("Invalid http response");
		kv.Close();
		return;
	}
	
	char szBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "data/etf2l/%s.vdf", szAuth);
	kv.ExportToFile(szBuffer);
	
	if(client)	g_Cache.Add(client, kv);
	kv.Close();
	
	if(client && IsClientInGame(client) && g_Config.Announce)
		AnnoncePlayerToAll(client);
}

void AnnoncePlayerToAll(int client)
{
	char szMsg[253];
	if(!g_Cache.GetAnnonceMsg(client, szMsg, sizeof(szMsg)))
		return;
	
	bool bAdminsOnly = g_Config.AdminsOnly;
	for (int target = 1; target <= MaxClients; ++target)
	{
		if(!IsClientInGame(target) || IsFakeClient(target))
			continue;
		
		if(bAdminsOnly && !GetUserFlagBits(target))
			continue;
		
		CPrintToChatEx(target, client, szMsg);
	}
}