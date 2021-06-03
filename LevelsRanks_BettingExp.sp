#include <lvl_ranks>
#include <devcolors> // Multiversion colour

#if SOURCEMOD_V_MINOR < 10 
---> #error This plugin only compile on SM 1.10
#endif

int PBet[MAXPLAYERS + 1], PTeam[MAXPLAYERS + 1], Used[MAXPLAYERS + 1];

int Per, MinPL, MinBet, MaxBet, PerRnd, BStart = 0;

Handle TMenu, BMenu, Plant, OvO;

float BetMult;

bool BetDead, Adv, CBet, BombPlant, OvOB;

public Plugin myinfo = 
{
	name = "[LVL] Betting Exp",
	description = "Betting Exp On Team",
	author = "-=HellFire=-",
	version = "1.0.0",
	url = "VK: vk.com/insellx | HLMOD: hlmod.ru/members/hellfire.105029"
};

public void OnPluginStart()
{
	ConVar CVar;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_period", "120", "Действие ставок после начала раунда (секунды)")), CVar_Period);
	Per = CVar.IntValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_minpl", "4", "Минимальное кол-во игроков для работы ставок")), CVar_MinPl);
	MinPL = CVar.IntValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_mult", "2.0", "Коэффициент ставок")), CVar_BetMult);
	BetMult = CVar.FloatValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_onlydead", "0", "Ставки только для мертвых - 0 = выкл")), CVar_BetDead);
	BetDead = CVar.BoolValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_minbet", "50", "Минимальная ставка")), CVar_MinBet);
	MinBet = CVar.IntValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_maxbet", "200", "Максимальная ставка")), CVar_MaxBet);
	MaxBet = CVar.IntValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlvet_betround", "2", "Кол-во ставок на раунд - 0 = бесконечно")), CVar_PerRnd);
	PerRnd = CVar.IntValue;

	HookConVarChange((CVar = CreateConVar("sm_lvlbet_advert", "1", "Информация о ставках в начале раунда - 0 = выкл")), CVar_Advert);
	Adv = CVar.BoolValue;

	Plant = CreateConVar("sm_lvlbet_bombplant", "1", "Запретить ставки после закладки бомбы - 0 = выкл");

	OvO = CreateConVar("sm_lvlbet_onevsone", "1", "Включить ставку при 1 на 1"); // Них*я нормально не работает, при дисконнекте слетает.
	OvOB = GetConVarBool(OvO);

	HookEvent("round_start", RoundStart, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("bomb_planted", Planted, EventHookMode_PostNoCopy);
	HookEvent("player_death", PlayerDeath, EventHookMode_Post);
	
	AutoExecConfig(true, "lvlbetting");

	LoadTranslations("lvlbetting.phrases");
	
	RegConsoleCmd("sm_lbet", Bet);

	BetMenu();
}

public void CVar_Period(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	Per = CVar.IntValue;
}

public void CVar_MinPl(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	MinPL = CVar.IntValue;
}

public void CVar_MinBet(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	MinBet = CVar.IntValue;
}

public void CVar_MaxBet(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	MaxBet = CVar.IntValue;
}

public void CVar_PerRnd(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	PerRnd = CVar.IntValue;
}

public void CVar_Advert(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	Adv = CVar.BoolValue;
}

public void CVar_BetDead(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	BetDead = CVar.BoolValue;
}

public void CVar_BetMult(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	BetMult = CVar.FloatValue;
}

public void OnClientDisconnect(int client)
{
	if (PBet[client])
	{
		LR_ChangeClientValue(client, PBet[client]);
		PBet[PTeam[Used[client]]] = 0;
	}
}

void BetMenu()
{
	TMenu = CreateMenu(TMenuHandler);
	SetMenuTitle(TMenu, "Выберите команду:\n \n");
	AddMenuItem(TMenu, "t", "Террористы");
	AddMenuItem(TMenu, "ct", "Контр-Террористы");
	SetMenuExitBackButton(TMenu, false);
	
	BMenu = CreateMenu(BMenuHandler);
	SetMenuTitle(BMenu, "Кол-во ставки:\n \n");
	AddMenuItem(BMenu, "50", "50 опыта");
	AddMenuItem(BMenu, "100", "100 опыта");
	AddMenuItem(BMenu, "150", "150 опыта");
	AddMenuItem(BMenu, "200", "200 опыта");
	AddMenuItem(BMenu, "250", "250 опыта");
	AddMenuItem(BMenu, "300", "300 опыта");
	SetMenuExitBackButton(BMenu, false);
}

public int TMenuHandler(Menu menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			if (!slot)
			{
				PTeam[client] = 2;
				DisplayMenu(BMenu, client, 15);
			}
			switch (slot)
			{
				case 1:
				{
					PTeam[client] = 3;
					DisplayMenu(BMenu, client, 15);
				}
			}
		}
	}
}

public int BMenuHandler(Menu menu, MenuAction action, int client, int slot)
{
	switch (action)
	{
		/*case MenuAction_End:
    	{
			delete BMenu;
    	}*/
		case MenuAction_Cancel:
		{
			if (!PBet[client])
			{
				PTeam[client] = 0;
			}
		}
		case MenuAction_Select:
		{
			char infoBuf[8], sTeam[16];
			GetMenuItem(menu, slot, infoBuf, sizeof(infoBuf));

			int bet = StringToInt(infoBuf);
			int iexp = LR_GetClientInfo(client, ST_EXP);
			if (bet < MinBet)
			{
				DCPrintToChat(client, "%t", "MinExp", MinBet, bet);
				//DCPrintToChat(client, "[LVL-BET] Вы не можете поставить меньше, чем [%d опыта], Ваша ставка: [%d]", MinBet, bet);
				// В игре - [LVL-BET] Вы не можете поставить меньше, чем 110 опыта, Ваша ставка: {1}
			}
			else if (bet > MaxBet || PBet[client] > MaxBet)
			{
				DCPrintToChat(client, "%t", "MaxExp", MaxBet, bet);
				//DCPrintToChat(client, "[LVL-BET] Вы не можете поставить больше, чем [%d опыта], Ваша ставка: [%d]", MaxBet, bet);
			}
			else if (bet < iexp)
			{
				PBet[client] += bet;

				switch (PTeam[client])
				{
					case 3: strcopy(sTeam, sizeof(sTeam), "КТ");
					case 2: strcopy(sTeam, sizeof(sTeam), "Т");
				}
				DCPrintToChat(client, "%t", "BetExp", PBet[client], sTeam);
				DCPrintToChat(client, "%t", "WinExp", RoundToCeil(PBet[client] * BetMult));
				LR_ChangeClientValue(client, -bet);
				Used[client]++;
			}
			else
			{
				DCPrintToChat(client, "%t", "NotExp", iexp);
			}
			if (!PBet[client])
			{
				PTeam[client] = 0;
			}
		}
	}
}

public Action Bet(int client, int args)
{			
	if (IsClientInGame(client))
	{
		if (!CBet)
		{
			DCPrintToChat(client, "%t", "NotBet");
			return Plugin_Handled;
		}
		else if (BombPlant)
		{
			DCPrintToChat(client, "%t", "Planted");
			return Plugin_Handled;
		}
		else if (OvOB)
		{
			DCPrintToChat(client, "%t", "OneVsOne");
			return Plugin_Handled;
		}
		else if (BetDead)
		{
			if (IsPlayerAlive(client))
			{
				DCPrintToChat(client, "%t", "BetDead");
				return Plugin_Handled;
			}
		}
		if (GetClientCount() < MinPL)
		{
			DCPrintToChat(client, "%t", "MinPlayers", MinPL);
			return Plugin_Handled;
		}
		else if (Per && BStart + Per < GetTime())
		{
			DCPrintToChat(client, "%t", "Period");
			return Plugin_Handled;
		}
		else if (PerRnd && Used[client] >= PerRnd)
		{
			DCPrintToChat(client, "%t", "UsedRound", PerRnd);
			return Plugin_Handled;
		}
		else if (args != 2)
		{
			DisplayMenu(TMenu, client, 20);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

public void RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CBet = true; BStart = GetTime();

	for (int i = 1; i <= MaxClients; i++)
	{
		PBet[PTeam[Used[i]]] = 0;
		if (Adv && GetClientCount() < MinPL)
		{
			DCPrintToChatAll("%t", "Advertisement");
		}
	}
}

public void Planted(Event event, const char[] name, bool dontBroadcast)
{
	if (GetConVarInt(Plant) == 1)
	{
		BombPlant = true;
	}
}

public void RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	CBet = false; BombPlant = false; OvOB = false;

	int iWinnerTeam = GetEventInt(event, "winner");
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && PBet[i])
		{
			if (PTeam[i] != iWinnerTeam)
			{
				DCPrintToChat(i, "%t", "LoseBet", PBet[i]);
			}
			else
			{
				PBet[i] = RoundToCeil(PBet[i] * BetMult);
				LR_ChangeClientValue(i, PBet[i]);
				DCPrintToChat(i, "%t", "WinBet", PBet[i]);
			}
		}
		Used[i] = 0; PBet[i] = 0;
	}
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int CT, T = 0;
	for (int i = 1; i < MaxClients; i++) 
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && IsPlayerAlive(i)) 
		{
			if(GetClientTeam(i) == 2) 
			{
				CT++;
			} 
			else 
			{
				T++;
			}
		}
	}
	if(OvOB && CT == 1 && T == 1)
	{
		for (int i = 1; i < MaxClients; i++) 
		{
			if(IsClientInGame(i) && !IsFakeClient(i) && !IsPlayerAlive(i))
			DisplayMenu(TMenu, i, 20);
		}
	}
}