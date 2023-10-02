#if defined _etf2l_cache_included
#endinput
#endif
#define _etf2l_cache_included

methodmap Cache < KeyValues
{
	public Cache()
	{
		return view_as<Cache>(new KeyValues("cache"));
	}
	
	public bool IsClientCached(int client)
	{
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		return this.JumpToKey(szUserID);
	}
	
	public bool IsClientBanned(int client)
	{
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		return this.JumpToKey(szUserID) && this.GetNum("ban", 0);
	}
	
	public int GetClientId(int client)
	{
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		return this.JumpToKey(szUserID) ? this.GetNum("id", -1) : -1;
	}
	
	public bool Add(int client, KeyValues data)
	{
		if(this.IsClientCached(client))
			return false;
		
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		data.Rewind();
		if(this.JumpToKey(szUserID, true) && data.JumpToKey("player"))
		{
			int id = data.GetNum("id", -1);
			this.SetNum("id", id);
			if(id == -1)
				return true;
			
			char szBuffer[256];
			data.GetString("name", szBuffer, sizeof(szBuffer));
			this.SetString("name", szBuffer);
			
			data.GetString("country", szBuffer, sizeof(szBuffer));
			this.SetString("country", szBuffer);
			
			szBuffer[0] = '\0';
			if(data.JumpToKey("steam"))
			{
				data.GetString("id", szBuffer, sizeof(szBuffer));
				data.GoBack();
			}
			
			this.SetString("steam_id", szBuffer);
			
			if(data.JumpToKey("bans"))
			{
				if(data.GotoFirstSubKey())
				{
					int now = GetTime();
					
					do
					{
						int end = data.GetNum("end", 0);
						if(end && end > now)
						{
							this.SetNum("ban", 1);
							return true;
						}
					}
					while (data.GotoNextKey());
					
					data.GoBack();
				}
				
				data.GoBack();
			}
			
			if(this.JumpToKey("teams", true) && data.JumpToKey("teams") && data.GotoFirstSubKey())
			{
				char szTeamType[32], szTeamName[256], szEvent[256], szDivision[256], szTemp[256];
				int index = 0;
				
				do
				{
					data.GetString("type", szTeamType, sizeof(szTeamType));
					data.GetString("name", szTeamName, sizeof(szTeamName));
					
					if(data.JumpToKey("competitions"))
					{
						if(data.GotoFirstSubKey())
						{
							int highest = -1;
							
							do
							{
								data.GetSectionName(szBuffer, sizeof(szBuffer));
								int competition_id = StringToInt(szBuffer);
								if(competition_id > highest)
								{
									szTemp[0] = '\0';
									if(data.JumpToKey("division"))
									{
										data.GetString("name", szTemp, sizeof(szTemp));
										data.GoBack();
									}
									
									if(szTemp[0])
									{
										highest = competition_id;
										
										data.GetString("competition", szEvent, sizeof(szEvent));
										strcopy(szDivision, sizeof(szDivision), szTemp);
									}
								}
							}
							while (data.GotoNextKey());
							
							data.GoBack();
						}
						
						data.GoBack();
					}
					
					IntToString(index, szBuffer, sizeof(szBuffer));
					if(this.JumpToKey(szBuffer, true))
					{
						this.SetString("name", szTeamName);
						this.SetString("type", szTeamType);
						this.SetString("event", szEvent);
						this.SetString("division", szDivision);
						
						this.GoBack();
						++index;
					}
				}
				while (data.GotoNextKey());
				
				this.GoBack();
				this.SetNum("teams_num", index);
			}
			
			return true;
		}
		
		return false;
	}
	
	public bool Remove(int client)
	{
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		if(this.JumpToKey(szUserID))
		{
			this.DeleteThis();
			return true;
		}
		
		return false;
	}
	
	public void ClearCache()
	{
		this.Rewind();
		if(this.GotoFirstSubKey())
		{
			do
			{
				this.DeleteThis();
				this.Rewind();
			}
			while (this.GotoFirstSubKey());
		}
	}
	
	public Panel GetInfoPanel(int client)
	{
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		if(!this.JumpToKey(szUserID))
			return null;
		
		int id = this.GetNum("id", -1);
		if(id == -1)
			return null;
		
		Panel panel = new Panel();
		
		char szDisplay[256], szBuffer[256], szCountry[32];
		this.GetString("name", szBuffer, sizeof(szBuffer));
		this.GetString("country", szCountry, sizeof(szCountry));
		Format(szDisplay, sizeof(szDisplay), "%N - %s\n%s\n ", client, szBuffer, szCountry);
		panel.SetTitle(szDisplay);
		
		if(this.JumpToKey("teams") && this.GotoFirstSubKey())
		{
			char szDevision[32], szEvent[256], szTeamType[32];
			
			do
			{
				this.GetString("type", szTeamType, sizeof(szTeamType));
				this.GetString("name", szBuffer, sizeof(szBuffer));
				this.GetString("division", szDevision, sizeof(szDevision));
				this.GetString("event", szEvent, sizeof(szEvent));
				
				if(szDevision[0])
				{
					Format(szDisplay, sizeof(szDisplay), "%s: %s\n%s # %s\n ", szTeamType, szBuffer, szDevision, szEvent);
				}
				else
				{
					Format(szDisplay, sizeof(szDisplay), "%s: %s\ninactive\n ", szTeamType, szBuffer);
				}
				
				panel.DrawText(szDisplay);
			}
			while (this.GotoNextKey());
		}
		
		panel.DrawItem("Back");
		panel.DrawItem("Exit");
		
		return panel;
	}
	
	public int GetAnnonceMsg(int client, char[] szBuffer, int maxlen)
	{
		int len = Format(szBuffer, maxlen, "{teamcolor}%N{default}", client);
		
		char szUserID[12];
		IntToString(GetClientUserId(client), szUserID, sizeof(szUserID));
		
		this.Rewind();
		if(!this.JumpToKey(szUserID) || this.GetNum("id", -1) == -1)
		{
			len += Format(szBuffer[len], maxlen - len, " unregistered.");
			return len;
		}
		
		char szName[128], szCountry[32];
		this.GetString("name", szName, sizeof(szName));
		this.GetString("country", szCountry, sizeof(szCountry));
		
		if(szName[0])
			len += Format(szBuffer[len], maxlen - len, " - (%s), ", szName);
		else
			len += Format(szBuffer[len], maxlen - len, ", ");
		
		if(this.GetNum("ban", 0))
		{
			len += Format(szBuffer[len], maxlen - len, "{red}Banned{default}");
			if(szCountry[0])
				len += Format(szBuffer[len], maxlen - len, ", {lightgreen}%s{default}.", szCountry);
			return len;
		}
		
		char szType[32];
		g_Config.GetTeamType(szType, sizeof(szType));
		
		char szTeamName[128], szDivision[128], szEvent[128];
		if(this.JumpToKey("teams") && this.GotoFirstSubKey())
		{
			do
			{
				this.GetString("type", szName, sizeof(szName));
				if(StrContains(szName, szType, false) != -1)
				{
					this.GetString("name", szTeamName, sizeof(szTeamName));
					this.GetString("event", szEvent, sizeof(szEvent));
					this.GetString("division", szDivision, sizeof(szDivision));
					//break;
				}
			}
			while (this.GotoNextKey());
		}
		
		if(szTeamName[0])
		{
			len += Format(szBuffer[len], maxlen - len, "{lightgreen}%s{default} # ", szTeamName);
			
			if(szDivision[0])
			{
				len += Format(szBuffer[len], maxlen - len, "{olive}%s{default}, {olive}%s{default}", szDivision, szEvent);
			}
			else
				len += Format(szBuffer[len], maxlen - len, "{lightgreen}inactive{default}");
			
			if(szCountry[0])
				len += Format(szBuffer[len], maxlen - len, ", {lightgreen}%s{default}.", szCountry);
		}
		else
		{
			len += Format(szBuffer[len], maxlen - len, "{lightgreen}no team{default}");
			
			if(szCountry[0])
				len += Format(szBuffer[len], maxlen - len, ", {lightgreen}%s{default}.", szCountry);
		}
		
		return len;
	}
};
