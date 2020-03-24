#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

/* 
1. Read client steamid and fetch mmr. if new player ask them for mmr or assume it is 3000
2. when 10 players are connected sort from high mmr to low mmr with rankings
3. sort teams based on ranks
4. join teams
*/

public Plugin:myinfo =
{
    name = "Dota 2 - Team Balancer",
    description = "Dota 2 - Team Balancer",
    author = "Sittingbull",
    version = "1.0",
    url = ""
};


new clients[10];
new client_count;
new teams_sorted;
Database db;

public OnPluginStart()
{
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	AddCommandListener(Command_mmr, "-mmr");
	char error[255];
	db = SQL_DefConnect(error, sizeof(error));
	if (db == null)
	{
	PrintToServer("Could not connect to sql: %s", error);
	}
	new i;
    while (i < 10)
    {
        clients[i] = CreateArray(32, 5);
        i++;
    }
}

public OnPluginEnd()
{
	CloseHandle(db);
}
public Action:Command_mmr(client, const String:command[], args)
{
	decl String:sayString[32];
	GetCmdArg(1,sayString,sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	int MMR = StringToInt(sayString);
	if (MMR == 0)
	{
		PrintToChat(client, "Please enter a valid integer after -mmr");
	}
	else 
	{
		PrintToChat(client, "Your mmr was registered as %d. If this is incorrect please re-enter the command.", MMR);
		new String:steamid[32];
		GetClientAuthId(client, AuthIdType:2, steamid, 32, true);
		UpdateMMR(steamid, MMR);
	}
}

public Action:Command_Say(client, const String:command[], args)
{
	decl String:sayString[32];
	GetCmdArg(1,sayString,sizeof(sayString));
	GetCmdArgString(sayString, sizeof(sayString));
	StripQuotes(sayString);
	new String:clientArg[32];
	int mmrIndex = BreakString(sayString, clientArg, sizeof(clientArg));
	if (!strcmp(clientArg,"-mmr",false))
	{
		if(mmrIndex == -1)
		{
			PrintToChat(client, "Please enter a valid integer after -mmr");
		}
		else
		{
			int MMR = StringToInt(sayString[mmrIndex]);
			if(MMR == 0)
			{
				PrintToChat(client, "Please enter a valid integer after -mmr");
			}
			else 
			{
				PrintToChat(client, "Your mmr was registered as %d. If this is incorrect please re-enter the command.", MMR);
				new String:steamid[32];
				GetClientAuthId(client, AuthIdType:2, steamid, 32, true);
				UpdateMMR(steamid, MMR);
			}
		}
	}
}

UpdateMMR(String:steamid[],int MMR)
{
	int i;
	while (i<10)
	{
		new String:steamidcheck[32];
		GetArrayString(clients[i], 1, steamidcheck, sizeof(steamidcheck));
		if(!strcmp(steamidcheck,steamid))
		{
			if(!GetArrayCell(clients[i],4))
			{
				return;
			}
			SetArrayCell(clients[i], 2, MMR);
			PrintToServer("Updated MMR is %d", MMR);
		}
		i++;
	}
	
	new String:MMRquery[200];
	Format(MMRquery, 200, "SELECT mmr FROM leaderboard WHERE steamid = '%s'", steamid);
	DBResultSet query = SQL_Query(db, MMRquery); 
	new String:error[1024];
	if (SQL_FetchRow(query))
	{
		Format(MMRquery, 200, "UPDATE leaderboard SET mmr=%d WHERE steamid = '%s'",MMR,steamid);
		if (!(SQL_Query(db, MMRquery)))
        {
        	SQL_GetError(db, error, 1024);
            PrintToServer("Failed to update leaderboard (error: %s)", error);
        }
	}
	else
	{
		Format(MMRquery, 200, "INSERT INTO leaderboard (steamid, mmr) VALUES ('%s','%d')", steamid, MMR);
		if (!(SQL_Query(db, MMRquery)))
		{
			SQL_GetError(db, error, 1024);
			PrintToServer("Failed to insert into leaderboard (error: %s)", error);
        }
	}
}

GetMMR(String:steamid[],int i,int client)
{
	new MMR;
	new String:MMRquery[200];
	Format(MMRquery, 200, "SELECT mmr FROM leaderboard WHERE steamid = '%s'", steamid);
	DBResultSet query = SQL_Query(db, MMRquery); 
	if (SQL_FetchRow(query))
	{
		MMR = SQL_FetchInt(query, 0);
		PrintToServer("MMR %d", MMR);
		SetArrayCell(clients[i], 2, MMR);
	}
	else
	{
		CreateTimer(2.0, TimerCallBack, client);
		MMR = 3000;
		SetArrayCell(clients[i], 2, MMR);
		SetArrayCell(clients[i], 4, 1);
	}
}

public Action:TimerCallBack(Handle:timer, any:client)
{
	PrintToChat(client, "(Private Message) Your mmr wasn't found. Please enter '-mmr [your mmr]' into chat or console so that teams can be fairly balanced.");
}

public void OnClientPostAdminCheck(client)
{
	if(IsClientSourceTV(client))
	{
		return;
	}
	new String:steamid[32];
	new i;
	while(i < 10&&!teams_sorted)
	{
		if(!GetArrayCell(clients[i],3))
		{
			GetClientAuthId(client, AuthIdType:2, steamid, 32, true);
			SetArrayCell(clients[i], 0, client);
			SetArrayString(clients[i], 1, steamid);
			GetMMR(steamid,i,client);
			SetArrayCell(clients[i], 3, 1);
			PrintToServer("client %d steamid %s MMR %d t/f %d", client, steamid, GetArrayCell(clients[i], 2), GetArrayCell(clients[i], 3));
			client_count++;
			new String:clientname[32];
			GetClientName(client, clientname, 32);
			PrintToChatAll("%s has connected. %d/10 players have connected.",clientname,client_count);
			i = 10;
		}
		i++;
	}
	if(client_count==10&&!teams_sorted)
	{
		TeamSort(clients);
		CloseHandle(db);
		teams_sorted = 1;
		
	}
}

public void OnClientDisconnect(client)
{
	//delete info from clients[]
	new i;
	while (i < 10)
	{
		if (GetArrayCell(clients[i],0) == client)
		{
			SetArrayCell(clients[i], 3, 0);
			client_count = client_count - 1;
			return;
		}
		i++;
	}
}

TeamSort(adt_array[])
{
	new i;
	new MMR[10];
	new ranks[10];
	while (i < 10)
	{
		MMR[i] = GetArrayCell(adt_array[i], 2);
		i++;
	}
	SortIntegers(MMR,10,Sort_Descending);
	new j;
	new rank1filled;
	new rank2filled;
	new rank3filled;
	new rank4filled;
	new rank5filled;
	new rank6filled;
	new rank7filled;
	new rank8filled;
	new rank9filled;
	new rank10filled;
	while (j < 10)
	{
		new ranked;
		if(GetArrayCell(adt_array[j],2)==MMR[0]&&!rank1filled&&!ranked)
		{
			ranks[0] = GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 1 is client %d", GetArrayCell(adt_array[j], 0));
			rank1filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[1]&&!rank2filled&&!ranked)
		{
			ranks[1]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 2 is client %d", GetArrayCell(adt_array[j], 0));
			rank2filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[2]&&!rank3filled&&!ranked)
		{
			ranks[2]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 3 is client %d", GetArrayCell(adt_array[j], 0));
			rank3filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[3]&&!rank4filled&&!ranked)
		{
			ranks[3]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 4 is client %d", GetArrayCell(adt_array[j], 0));
			rank4filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[4]&&!rank5filled&&!ranked)
		{
			ranks[4]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 5 is client %d", GetArrayCell(adt_array[j], 0));
			rank5filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[5]&&!rank6filled&&!ranked)
		{
			ranks[5]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 6 is client %d", GetArrayCell(adt_array[j], 0));
			rank6filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[6]&&!rank7filled&&!ranked)
		{
			ranks[6]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 7 is client %d", GetArrayCell(adt_array[j], 0));
			rank7filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[7]&&!rank8filled&&!ranked)
		{
			ranks[7]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 8 is client %d", GetArrayCell(adt_array[j], 0));
			rank8filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[8]&&!rank9filled&&!ranked)
		{
			ranks[8]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 9 is client %d", GetArrayCell(adt_array[j], 0));
			rank9filled = 1;
			ranked = 1;
		}
		else if(GetArrayCell(adt_array[j],2)==MMR[9]&&!rank10filled&&!ranked)
		{
			ranks[9]= GetArrayCell(adt_array[j], 0);
			PrintToServer("rank 10 is client %d", GetArrayCell(adt_array[j], 0));
			rank10filled = 1;
			ranked = 1;
		}
		j++;
	}
	new arrangement = GetRandomInt(0, 5);
	switch(arrangement)
	{
		case 0:
		{
			FakeClientCommand(ranks[2], "jointeam good");
			FakeClientCommand(ranks[1], "jointeam good");
			FakeClientCommand(ranks[4], "jointeam good");
			FakeClientCommand(ranks[7], "jointeam good");
			FakeClientCommand(ranks[8], "jointeam good");
			FakeClientCommand(ranks[0], "jointeam bad");
			FakeClientCommand(ranks[3], "jointeam bad");
			FakeClientCommand(ranks[5], "jointeam bad");
			FakeClientCommand(ranks[6], "jointeam bad");
			FakeClientCommand(ranks[9], "jointeam bad");
		}
		case 1:
		{
			FakeClientCommand(ranks[0], "jointeam good");
			FakeClientCommand(ranks[3], "jointeam good");
			FakeClientCommand(ranks[5], "jointeam good");
			FakeClientCommand(ranks[6], "jointeam good");
			FakeClientCommand(ranks[9], "jointeam good");
			FakeClientCommand(ranks[1], "jointeam bad");
			FakeClientCommand(ranks[1], "jointeam bad");
			FakeClientCommand(ranks[4], "jointeam bad");
			FakeClientCommand(ranks[7], "jointeam bad");
			FakeClientCommand(ranks[8], "jointeam bad");
		}
		case 2:
		{
			FakeClientCommand(ranks[1], "jointeam good");
			FakeClientCommand(ranks[2], "jointeam good");
			FakeClientCommand(ranks[3], "jointeam good");
			FakeClientCommand(ranks[7], "jointeam good");
			FakeClientCommand(ranks[9], "jointeam good");
			FakeClientCommand(ranks[0], "jointeam bad");
			FakeClientCommand(ranks[4], "jointeam bad");
			FakeClientCommand(ranks[5], "jointeam bad");
			FakeClientCommand(ranks[6], "jointeam bad");
			FakeClientCommand(ranks[8], "jointeam bad");
		
		}
		case 3:
		{
			FakeClientCommand(ranks[0], "jointeam good");
			FakeClientCommand(ranks[4], "jointeam good");
			FakeClientCommand(ranks[5], "jointeam good");
			FakeClientCommand(ranks[6], "jointeam good");
			FakeClientCommand(ranks[8], "jointeam good");
			FakeClientCommand(ranks[1], "jointeam bad");
			FakeClientCommand(ranks[2], "jointeam bad");
			FakeClientCommand(ranks[3], "jointeam bad");
			FakeClientCommand(ranks[7], "jointeam bad");
			FakeClientCommand(ranks[9], "jointeam bad");
		}
		case 4:
		{
			FakeClientCommand(ranks[0], "jointeam good");
			FakeClientCommand(ranks[2], "jointeam good");
			FakeClientCommand(ranks[5], "jointeam good");
			FakeClientCommand(ranks[7], "jointeam good");
			FakeClientCommand(ranks[9], "jointeam good");
			FakeClientCommand(ranks[1], "jointeam bad");
			FakeClientCommand(ranks[3], "jointeam bad");
			FakeClientCommand(ranks[4], "jointeam bad");
			FakeClientCommand(ranks[6], "jointeam bad");
			FakeClientCommand(ranks[8], "jointeam bad");
		}
		case 5:
		{
			FakeClientCommand(ranks[1], "jointeam good");
			FakeClientCommand(ranks[3], "jointeam good");
			FakeClientCommand(ranks[4], "jointeam good");
			FakeClientCommand(ranks[6], "jointeam good");
			FakeClientCommand(ranks[8], "jointeam good");	
			FakeClientCommand(ranks[0], "jointeam bad");
			FakeClientCommand(ranks[2], "jointeam bad");
			FakeClientCommand(ranks[5], "jointeam bad");
			FakeClientCommand(ranks[7], "jointeam bad");
			FakeClientCommand(ranks[9], "jointeam bad");
			
		}
	}
}