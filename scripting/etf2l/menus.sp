#if defined _etf2l_menus_included
#endinput
#endif
#define _etf2l_menus_included

void DisplayDivMenu(int client, int first_item = 0)
{
	Menu menu = new Menu(DivMenuHandler);
	
	char szInfo[128], szDisplay[128];
	for (int target = 1; target <= MaxClients; ++target)
	{
		if(!IsClientInGame(target) || IsFakeClient(target))
			continue;
		
		int id = g_Cache.GetClientId(target);
		bool bBanned = g_Cache.IsClientBanned(target);
		
		IntToString(GetClientUserId(target), szInfo, sizeof(szInfo));
		GetClientName(target, szDisplay, sizeof(szDisplay));
		
		if(id == -1)
			StrCat(szDisplay, sizeof(szDisplay), " [unregistered]");
		else if(bBanned)
			StrCat(szDisplay, sizeof(szDisplay), " [banned]");
		
		menu.AddItem(szInfo, szDisplay, (id == -1 || bBanned) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	
	menu.SetTitle("ETF2L\n ");
	menu.DisplayAt(client, first_item, MENU_TIME_FOREVER);
}

public int DivMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_End:
			menu.Close();
		
		case MenuAction_Select:
		{
			char szInfo[128];
			menu.GetItem(param, szInfo, sizeof(szInfo));
			int target = GetClientOfUserId(StringToInt(szInfo));
			if(target == 0)
			{
				PrintToChat(client, "Player not longer available");
				DisplayDivMenu(client, menu.Selection);
			}
			else
			{
				Panel panel = g_Cache.GetInfoPanel(target);
				if(panel == null)
				{
					DisplayDivMenu(client, menu.Selection);
				}
				else
				{
					panel.Send(client, DivPanelHandler, MENU_TIME_FOREVER);
					panel.Close();
				}
			}
		}
	}
}

public int DivPanelHandler(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_Cancel: {}
		case MenuAction_Select:
		{
			if(param == 1)
				DisplayDivMenu(client);
		}
	}
}