#if defined _etf2l_config_included
#endinput
#endif
#define _etf2l_config_included

#define DEFAULT_MAX_AGE 7
#define DEFAULT_ANNOUNCE 1
#define DEFAULT_ADMINS_ONLY 0
#define DEFAULT_SEASONS_ONLY 1
#define DEFAULT_TEAM_TYPE "6on6"

methodmap Config < KeyValues
{
	public Config()
	{
		char szBuffer[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, szBuffer, sizeof(szBuffer), "configs/etf2l.txt");
		if (!FileExists(szBuffer))
			SetFailState("Config file '%s' is not exists", szBuffer);
		
		KeyValues kv = new KeyValues("etf2l");
		if (!kv.ImportFromFile(szBuffer))
			SetFailState("Error reading config file '%s'. Check syntax.", szBuffer);
		
		return view_as<Config>(kv);
	}
	
	public void GetTeamType(char[] szBuffer, int maxlen)
	{
		this.Rewind();
		this.GetString("team_type", szBuffer, maxlen, DEFAULT_TEAM_TYPE);
	}
	
	property int MaxAge
	{
		public get()
		{
			this.Rewind();
			return this.GetNum("max_age", DEFAULT_MAX_AGE) * (24 * 60 * 60);
		}
	}
	
	property bool Announce
	{
		public get()
		{
			this.Rewind();
			return view_as<bool>(this.GetNum("announce", DEFAULT_ANNOUNCE));
		}
	}
	
	property bool AdminsOnly
	{
		public get()
		{
			this.Rewind();
			return view_as<bool>(this.GetNum("admins_only", DEFAULT_ADMINS_ONLY));
		}
	}
	
	property bool SeasonsOnly
	{
		public get()
		{
			this.Rewind();
			return view_as<bool>(this.GetNum("seasons_only", DEFAULT_SEASONS_ONLY));
		}
	}
};
