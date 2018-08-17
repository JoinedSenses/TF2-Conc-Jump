
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>
#include <smlib>

#define PLUGIN_VERSION "1.2.0"

public Plugin:myinfo = {
	name = "Concussion Grenade",
	author = "CrancK",
	description = "gives specified classes the concussion grenade from other tf's",
	version = PLUGIN_VERSION,
	url = ""
};

#define DMG_GENERIC			0
#define DMG_CRUSH			(1 << 0)
#define DMG_BULLET			(1 << 1)
#define DMG_SLASH			(1 << 2)
#define DMG_BURN			(1 << 3)
#define DMG_VEHICLE			(1 << 4)
#define DMG_FALL			(1 << 5)
#define DMG_BLAST			(1 << 6)
#define DMG_CLUB			(1 << 7)
#define DMG_SHOCK			(1 << 8)
#define DMG_SONIC			(1 << 9)
#define DMG_ENERGYBEAM			(1 << 10)
#define DMG_PREVENT_PHYSICS_FORCE	(1 << 11)
#define DMG_NEVERGIB			(1 << 12)
#define DMG_ALWAYSGIB			(1 << 13)
#define DMG_DROWN			(1 << 14)
#define DMG_TIMEBASED			(DMG_PARALYZE | DMG_NERVEGAS | DMG_POISON | DMG_RADIATION | DMG_DROWNRECOVER | DMG_ACID | DMG_SLOWBURN)
#define DMG_PARALYZE			(1 << 15)
#define DMG_NERVEGAS			(1 << 16)
#define DMG_POISON			(1 << 17)
#define DMG_RADIATION			(1 << 18)
#define DMG_DROWNRECOVER		(1 << 19)
#define DMG_ACID			(1 << 20)
#define DMG_SLOWBURN			(1 << 21)
#define DMG_REMOVENORAGDOLL		(1 << 22)
#define DMG_PHYSGUN			(1 << 23)
#define DMG_PLASMA			(1 << 24)
#define DMG_AIRBOAT			(1 << 25)
#define DMG_DISSOLVE			(1 << 26)
#define DMG_BLAST_SURFACE		(1 << 27)
#define DMG_DIRECT			(1 << 28)
#define DMG_BUCKSHOT			(1 << 29)

#define SND_NADE_CONC "weapons/explode5.wav"
#define SND_THROWNADE "weapons/grenade_throw.wav"
#define SND_NADE_CONC_TIMER "weapons/det_pack_timer.wav"
//#define MDL_CONC "models/weapons/nades/duke1/w_grenade_conc.mdl"
#define MDL_CONC "models/conc/w_grenade_conc.mdl"

//#define SND_NADE_CONC_HIGHPITCH "weapons/det_pack_timer6.wav"
#define SND_NADE_CONC_HIGHPITCH "weapons/det_pack_timer62.wav"
 
//"player/taunt_heel_click.wav"
//playertaunt_helmet_hit
//replay/cameracontrolerror.wav
//replayrecord_fail.wav
//ui/message_update.wav
//ui/system_message_alert
//tools/ifm/beep.wav


//950.0, 0.4, 2.25

new Handle:cvConcEnabled = INVALID_HANDLE;
new Handle:cvConcClass = INVALID_HANDLE;
new Handle:cvConcRadius = INVALID_HANDLE;
new Handle:cvConcMax = INVALID_HANDLE;
new Handle:cvNadeDelay = INVALID_HANDLE;
new Handle:cvNadeTimer = INVALID_HANDLE;
new Handle:cvNadePhysics = INVALID_HANDLE;
new Handle:cvNadeDifGrav = INVALID_HANDLE;
new Handle:cvNadeTrail = INVALID_HANDLE;
new Handle:cvNadeSoundMode = INVALID_HANDLE;
new Handle:cvNadeThrowSpeed = INVALID_HANDLE;
new Handle:cvNadeThrowAngle = INVALID_HANDLE;
new Handle:cvConcIgnore = INVALID_HANDLE;
new Handle:cvConcNoOtherPush = INVALID_HANDLE;
new Handle:cvConcRings = INVALID_HANDLE;
new Handle:cvConcBaseHeight = INVALID_HANDLE;
new Handle:cvConcBaseSpeed = INVALID_HANDLE;
new Handle:cvNadeIcon = INVALID_HANDLE;
new Handle:cvNadeHHHeight = INVALID_HANDLE;
new Handle:cvNadeHHDisDecrease = INVALID_HANDLE;
new Handle:cvBlastDistanceMin = INVALID_HANDLE;
new Handle:cvConcBounce = INVALID_HANDLE;
new Handle:cvConcHHBoost = INVALID_HANDLE;
new Handle:cvNadeAngleCorrection = INVALID_HANDLE;
new Handle:cvNadeWaitPeriod = INVALID_HANDLE;
new Handle:cvConcTest = INVALID_HANDLE;
new Handle:cvConcBounceDelay = INVALID_HANDLE;
new Handle:cvFrameTimer = INVALID_HANDLE;
new Handle:cvNadeGroundRes = INVALID_HANDLE;
new Handle:cvNadeStartHeight = INVALID_HANDLE;
new Handle:cvConcDebug = INVALID_HANDLE;

new gRingModel;	
new bool:holding[MAXPLAYERS][10];
new nadesUsed[MAXPLAYERS];
new concToUse[MAXPLAYERS];
new nadeId[MAXPLAYERS][10];
new Float:nadeTime[MAXPLAYERS][10];
new bool:nadeDelay[MAXPLAYERS];
new bool:buttonDown[MAXPLAYERS];
new bool:concHelp[MAXPLAYERS];
new Float:PlayersInRange[MAXPLAYERS];
new bool:canThrow = false;
new bool:waitOver = false;
new realStart = 0;
new Handle:HudMsg[MAXPLAYERS][10];
new Handle:timeTimer[MAXPLAYERS][10];
new nadeType[MAXPLAYERS][10];
new helpCounter[MAXPLAYERS][10];
new Float:holdingArea[3] = { -10000.0, -10000.0, -10000.0 };
new Float:personalTimer[MAXPLAYERS];
new Float:lastTime[MAXPLAYERS][10];
new Float:lastTime2[MAXPLAYERS][10];

new Float:lastOri[MAXPLAYERS][10][2][3];
new frameTimer[MAXPLAYERS][10];

public OnPluginStart() 
{
	CreateConVar("sm_conc_version", PLUGIN_VERSION, "Conc Version", FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvConcEnabled = CreateConVar("sm_nade_enabled", "1", "Enables the plugin", FCVAR_PLUGIN);
	cvNadeWaitPeriod = CreateConVar("sm_nade_waitperiod", "0", "Reccomended if you have setuptime");
	cvConcClass = CreateConVar("sm_conc_class", "scout,medic", "Which classes are able to use the conc command", FCVAR_PLUGIN);
	cvConcRadius = CreateConVar("sm_conc_radius", "288.0", "Radius of conc blast", FCVAR_PLUGIN);
	cvConcMax = CreateConVar("sm_conc_max", "4", "How many concs a player can have spawned at the same time", FCVAR_PLUGIN);
	cvNadeDelay = CreateConVar("sm_nade_delay", "0.55", "How long a player has to wait before throwing another conc", FCVAR_PLUGIN);
	cvNadeTimer = CreateConVar("sm_nade_timer", "3.0", "How many second to wait until conc explodes", FCVAR_PLUGIN);
	cvNadePhysics = CreateConVar("sm_nade_physics", "0", "Throwing physics, 0 = sm_conc_throwspeed, 1 = sm_conc_throwspeed+ownspeed, 2 = mix", FCVAR_PLUGIN);
	cvNadeDifGrav = CreateConVar("sm_nade_difgrav", "1.75", "Since prop_physics don't use the same physics as a player, this is needed to give it the same terminal velocity", FCVAR_PLUGIN);
	cvNadeTrail = CreateConVar("sm_nade_trail", "1", "Enables a trail following the conc", FCVAR_PLUGIN);
	cvNadeSoundMode = CreateConVar("sm_nade_sounds", "1", "0 = sounds only for client throwing them, 1 = sounds audible for everyone", FCVAR_PLUGIN);
	cvNadeThrowSpeed = CreateConVar("sm_nade_throwspeed", "625.0", "Speed at which concs are thrown", FCVAR_PLUGIN);
	cvNadeThrowAngle = CreateConVar("sm_nade_throwangle", "20.0", "Positive aims higher then crosshair, negative lower", FCVAR_PLUGIN);
	cvConcIgnore = CreateConVar("sm_conc_ignorewalls", "1", "Enables the conc's explosion to push people through walls", FCVAR_PLUGIN);
	cvConcNoOtherPush = CreateConVar("sm_conc_ignoreothers", "1", "Enables the conc's to only push the person that threw it", FCVAR_PLUGIN);
	cvConcRings = CreateConVar("sm_conc_rings", "10.0", "Sets how many rings the conc explosion has", FCVAR_PLUGIN);
	cvConcBaseHeight = CreateConVar("sm_nade_baseheight", "48.0", "Correction for how high the player is when exploding, for making sure it pushes ppl off ground", FCVAR_PLUGIN);
	cvConcBaseSpeed = CreateConVar("sm_conc_basespeed", "950.0", "Base value for conc speed calculations", FCVAR_PLUGIN);
	cvNadeIcon = CreateConVar("sm_nade_killicon", "tf_projectile_rocket", "kill icon for concs", FCVAR_PLUGIN);
	cvNadeHHHeight = CreateConVar("sm_nade_hhheight", "24.0", "How high a nade should be spawned relative to feet on a handheld(feet = 0.0)", FCVAR_PLUGIN);
	cvNadeHHDisDecrease = CreateConVar("sm_nade_hhdisdec", "0.175", "This value*playerspeed = distance from you and nade on a handheld", FCVAR_PLUGIN);
	cvConcBounce = CreateConVar("sm_conc_bounce", "1", "Insures a conc has the power to push someone back up, no matter how fast he's falling", FCVAR_PLUGIN);
	cvConcHHBoost = CreateConVar("sm_conc_hhboost", "3.0", "Correction for hh speed");
	cvNadeAngleCorrection = CreateConVar("sm_conc_anglecorr", "90.0", "Correction for angle which conc rolls to");
	cvBlastDistanceMin = CreateConVar("sm_conc_blastdistmin", "0.25", "...");
	cvConcBounceDelay = CreateConVar("sm_conc_bounce_delay", "0.0608", "...");
	cvFrameTimer = CreateConVar("sm_frametimer", "1", "...");
	cvConcTest = CreateConVar("sm_conc_testblast", "1", "...");
	cvNadeGroundRes = CreateConVar("sm_nade_groundres", "0.6", "...");
	cvNadeStartHeight = CreateConVar("sm_nade_startheight", "-24.0", "...");
	cvConcDebug = CreateConVar("sm_conc_debug", "0", "...");

	RegConsoleCmd("+conc", Command_Conc);
	RegConsoleCmd("-conc", Command_UnConc); //
	RegConsoleCmd("sm_conchelp", Command_ConcHelp);
	RegConsoleCmd("sm_conctimer", Command_ConcTimer);
	HookEvent("teamplay_restart_round", EventRestartRound);
	HookEvent("player_death",EventPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_start", MainEvents);
	HookEvent("teamplay_round_active", MainEvents);
	HookEvent("teamplay_round_stalemate", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("teamplay_game_over", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_changeclass", EventPlayerChangeClass);
	for(new i=0;i<MAXPLAYERS;i++)
	{
		personalTimer[i] = -1.0; //
		for(new j=0;j<10;j++)
		{
			HudMsg[i][j] = CreateHudSynchronizer();
			lastTime[i][j] = 0.0;
			lastTime2[i][j] = -1.0;
		}
	}
}

public OnMapStart()
{
	
	AddFileToDownloadsTable("models/conc/w_grenade_conc.vvd");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.sw.vtx");//
	AddFileToDownloadsTable("models/conc/w_grenade_conc.phy");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.mdl");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.dx90.vtx");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.dx80.vtx");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_blu.vmt");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_red.vmt");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_blu.vtf");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_red.vtf");
	
	AddFileToDownloadsTable("sound/weapons/det_pack_timer62.wav");
	//AddFolderToDownloadTable("models/conc");
	//AddFolderToDownloadTable("materials/conc");
	gRingModel = PrecacheModel("sprites/laser.vmt", true);
	PrecacheSound(SND_THROWNADE, true);
	PrecacheSound(SND_NADE_CONC, true);
	PrecacheSound(SND_NADE_CONC_TIMER, true);
	PrecacheSound(SND_NADE_CONC_HIGHPITCH, true);
	PrecacheModel(MDL_CONC, true);
	AddFileToDownloadsTable("models/conc/w_grenade_conc.vvd");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.sw.vtx");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.phy");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.mdl");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.dx90.vtx");
	AddFileToDownloadsTable("models/conc/w_grenade_conc.dx80.vtx");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_blu.vmt");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_red.vmt");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_blu.vtf");
	AddFileToDownloadsTable("materials/conc/w_grenade_conc_red.vtf");
	
	AddFileToDownloadsTable("sound/weapons/det_pack_timer62.wav");
	//AddFolderToDownloadTable("models/weapons/nades/duke1");
	//AddFolderToDownloadTable("materials/models/weapons/nades/duke1");
	
	canThrow = false;
	waitOver = false;
	for(new i=0;i<MAXPLAYERS;i++)
	{
		
		nadesUsed[i] = 0;
		concToUse[i] = -1;
		nadeDelay[i] = false;
		buttonDown[i] = false;
		concHelp[i] = false;
		
		for(new j=0;j<10;j++)
		{
			nadeId[i][j] = -1;
			nadeTime[i][j] = -1.0;
			holding[i][j] = false;
			nadeType[i][j] = -1;
			timeTimer[i][j] = INVALID_HANDLE;
			helpCounter[i][j] = -1;
			lastTime[i][j] = 0.0;
			lastTime2[i][j] = -1.0;
			
			lastOri[i][j][0][0] = 0.0;
			lastOri[i][j][0][1] = 0.0;
			lastOri[i][j][0][2] = 0.0;
			lastOri[i][j][1][0] = 0.0;
			lastOri[i][j][1][1] = 0.0;
			lastOri[i][j][1][2] = 0.0;
			frameTimer[i][j] = 0;
		}
	}
	
	
}

public OnMapEnd()
{
	canThrow = false;
	waitOver = false;
	for(new i=0;i<MAXPLAYERS;i++)
	{
		nadesUsed[i] = 0;
		concToUse[i] = -1;
		nadeDelay[i] = false;
		buttonDown[i] = false;
		concHelp[i] = false;
		personalTimer[i] = -1.0;
		for(new j=0;j<10;j++)
		{
			nadeId[i][j] = -1;
			nadeTime[i][j] = -1.0;
			holding[i][j] = false;
			nadeType[i][j] = -1;
			if(timeTimer[i][j]!=INVALID_HANDLE)
			{
				CloseHandle(timeTimer[i][j]); timeTimer[i][j] = INVALID_HANDLE;
			}
			helpCounter[i][j] = -1;
		}
	}
}

public OnClientPostAdminCheck(client)
{
	for(new i=0;i<10;i++)
	{
		if(nadeId[client][i] != -1 && IsValidEntity(nadeId[client][i])) { RemoveEdict(nadeId[client][i]); nadeId[client][i] = -1; }
		else if(nadeId[client][i] != -1) { nadeId[client][i] = -1; }
		nadeTime[client][i] = -1.0;
		holding[client][i] = false;
		nadeType[client][i] = -1;
		if(timeTimer[client][i]!=INVALID_HANDLE)
		{
			CloseHandle(timeTimer[client][i]); timeTimer[client][i] = INVALID_HANDLE;
		}
		helpCounter[client][i] = -1;
	}
	personalTimer[client] = -1.0;
	nadeDelay[client] = false;
	buttonDown[client] = false;
	concHelp[client] = false;
	concToUse[client] = -1;
	nadesUsed[client] = 0; //
	//SDKHook(client, SDKHook_PreThink, OnPreThink);
}

public OnClientDisconnect(client) 
{
	for(new i=0;i<10;i++)
	{
		if(nadeId[client][i] != -1 && IsValidEntity(nadeId[client][i])) { RemoveEdict(nadeId[client][i]); nadeId[client][i] = -1; }
		else if(nadeId[client][i] != -1) { nadeId[client][i] = -1; }
		nadeTime[client][i] = -1.0;
		holding[client][i] = false;
		nadeType[client][i] = -1;
		if(timeTimer[client][i]!=INVALID_HANDLE)
		{
			CloseHandle(timeTimer[client][i]); timeTimer[client][i] = INVALID_HANDLE;
		}
		helpCounter[client][i] = -1;
	}
	nadeDelay[client] = false;
	buttonDown[client] = false;
	concHelp[client] = false;
	concToUse[client] = -1;
	nadesUsed[client] = 0; //
	personalTimer[client] = -1.0;
}

public Action:EventRestartRound(Handle:event, const String:name[], bool:dontBroadcast) 
{
	if(GetConVarInt(cvConcEnabled)==1 && GetConVarInt(cvNadeWaitPeriod)==1)
	{
		waitOver = true;
		//PrintToChatAll("EventRestartRound");
		//PrintToServer("EventRestartRound");
	}
}

public Action:EventPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	new tClass = int:TF2_GetPlayerClass(client);
	new String:classString[16];
	switch(tClass)
	{
		case 1:	{ Format(classString, sizeof(classString), "scout"); }
		case 2: { Format(classString, sizeof(classString), "sniper"); }
		case 3: { Format(classString, sizeof(classString), "soldier"); }
		case 4: { Format(classString, sizeof(classString), "demoman"); }
		case 5: { Format(classString, sizeof(classString), "medic"); }
		case 6: { Format(classString, sizeof(classString), "heavy"); }
		case 7: { Format(classString, sizeof(classString), "pyro"); }
		case 8: { Format(classString, sizeof(classString), "spy"); }
		case 9: { Format(classString, sizeof(classString), "engineer"); }
	}
	if(IsClassAllowed(classString))
	{
		for(new i=0;i<10;i++)
		{
			if(holding[client][i])
			{
				ThrowNade(nadeId[client][i], false);
			}
		}
		/*
		while(!holding[client][nr] && nr<GetConVarInt(cvConcMax))
		{
			nr++;
		}
		if(nr < GetConVarInt(cvConcMax))
		{
			ThrowNade(client, false);
		}
		*/
	}
	else if(IsClassAllowed(classString))
	{
		for(new i=0;i<10;i++)
		{
			if(holding[client][i])
			{
				ThrowNade(nadeId[client][i], false);
			}
		}
		/*
		while(!holding[client][nr] && nr<GetConVarInt(cvFragMax))
		{
			nr++;
		}
		if(nr < GetConVarInt(cvFragMax))
		{
			ThrowNade(client, false);
		}
		*/
	}
}

public Action:EventPlayerChangeClass(Handle:event, const String:name[], bool:dontBroadcast) //fix for changing class -> removing concs so people cant cheat
{
	new client;
	client = GetClientOfUserId(GetEventInt(event, "userid"));
	new tClass = int:TF2_GetPlayerClass(client);
	new String:classString[16];
	switch(tClass)
	{
		case 1:	{ Format(classString, sizeof(classString), "scout"); }
		case 2: { Format(classString, sizeof(classString), "sniper"); }
		case 3: { Format(classString, sizeof(classString), "soldier"); }
		case 4: { Format(classString, sizeof(classString), "demoman"); }
		case 5: { Format(classString, sizeof(classString), "medic"); }
		case 6: { Format(classString, sizeof(classString), "heavy"); }
		case 7: { Format(classString, sizeof(classString), "pyro"); }
		case 8: { Format(classString, sizeof(classString), "spy"); }
		case 9: { Format(classString, sizeof(classString), "engineer"); }
	}
	if(!IsClassAllowed(classString))
	{
		for(new i=0;i<10;i++)
		{
			if(nadeId[client][i] != -1 && IsValidEntity(nadeId[client][i])) { RemoveEdict(nadeId[client][i]); nadeId[client][i] = -1; }
			else if(nadeId[client][i] != -1) { nadeId[client][i] = -1; }
			nadeTime[client][i] = -1.0;
			holding[client][i] = false;
			nadeType[client][i] = -1;
			if(timeTimer[client][i]!=INVALID_HANDLE)
			{
				CloseHandle(timeTimer[client][i]); timeTimer[client][i] = INVALID_HANDLE;
			}
			helpCounter[client][i] = -1;
		}
		nadeDelay[client] = false;
		buttonDown[client] = false;
		//concHelp[client] = false;
		concToUse[client] = -1;
		nadesUsed[client] = 0; //
		//personalTimer[client] = -1.0;
	}
}

public Action:MainEvents(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (waitOver && realStart%2 == 1 && GetConVarInt(cvNadeWaitPeriod)==1)
	{
		if (StrEqual(name, "teamplay_round_start"))
		{
			//PrintToChatAll("teamplay_round_start && waitover");
			//PrintToServer("teamplay_round_start && waitover");
			canThrow = false;
		}
		else if (StrEqual(name, "teamplay_round_active"))
		{
			//PrintToChatAll("teamplay_round_active && waitover");
			//PrintToServer("teamplay_round_active && waitover");
			realStart++;
			canThrow = true;
		}
	}
	else if(GetConVarInt(cvNadeWaitPeriod)==1)
	{
		if (StrEqual(name, "teamplay_round_start"))
		{
			//PrintToChatAll("teamplay_round_start && !waitover");
			//PrintToServer("teamplay_round_start && !waitover");
			canThrow = false;
		}
		else if (StrEqual(name, "teamplay_round_active"))
		{
			//PrintToChatAll("teamplay_round_active && !waitover");
			//PrintToServer("teamplay_round_active && !waitover");
			canThrow = false;
			realStart++;
		}
	}
	else
	{
		canThrow = true;
		waitOver = true;
	}
}

public Action:RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	//PrintToChatAll("EventRoundEnd");
	//PrintToServer("EventRoundEnd");
	if (StrEqual(name, "teamplay_game_over"))
	{
		waitOver = false;
		realStart = 0;
		canThrow = false;
	}
	canThrow = false;
	realStart = 1;
	//waitOver = false;
}

public OnEntityDestroyed(ent)
{
	if(GetConVarInt(cvConcEnabled)==1)
	{
		if(IsValidEntity(ent))
		{
			new nadeInfo[2]; nadeInfo = FindNade(ent);
			if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
			{
				new client = nadeInfo[0];
				new number = nadeInfo[1];
				nadeTime[client][number] = -2.0;
				nadeType[client][number] = -1;
				nadeId[client][number] = -1;
				if(timeTimer[client][number] != INVALID_HANDLE) { CloseHandle(timeTimer[client][number]); timeTimer[client][number] = INVALID_HANDLE; }
				helpCounter[client][number] = -1;
				nadesUsed[client]--;
			}
		}
	}
}

public Action:Command_Conc(client, args)
{
	if(GetConVarInt(cvConcEnabled)==1 && canThrow)
	{
		new tClass = int:TF2_GetPlayerClass(client);
		new String:classString[16];
		switch(tClass)
		{
			case 1:	{ Format(classString, sizeof(classString), "scout"); }
			case 2: { Format(classString, sizeof(classString), "sniper"); }
			case 3: { Format(classString, sizeof(classString), "soldier"); }
			case 4: { Format(classString, sizeof(classString), "demoman"); }
			case 5: { Format(classString, sizeof(classString), "medic"); }
			case 6: { Format(classString, sizeof(classString), "heavy"); }
			case 7: { Format(classString, sizeof(classString), "pyro"); }
			case 8: { Format(classString, sizeof(classString), "spy"); }
			case 9: { Format(classString, sizeof(classString), "engineer"); }
		}
		if(!IsPlayerAlive(client) || IsFakeClient(client) || IsClientObserver(client) || nadeDelay[client] || !IsClassAllowed(classString) || buttonDown[client])
		{
			return Plugin_Handled;
		}
		for(new i=0;i<10;i++)
		{
			if(holding[client][i] == true) { return Plugin_Handled; }
		}
		if(nadesUsed[client] < GetConVarInt(cvConcMax))
		{
			//new tNade = MakeNade(client);
			new tNade = MakeNade2(client);
			if(tNade > -1)
			{
				holding[client][tNade] = true;
				nadeDelay[client] = true;
				buttonDown[client] = true;
				nadesUsed[client]++;
				nadeTime[client][tNade] = 0.0;
				CreateTimer(1.0, beepTimer, nadeId[client][tNade]);
				//lastTime2[client][number] = GetGameTime();
				CreateTimer(GetConVarFloat(cvNadeDelay), delayTimer, client);
				if(concHelp[client])
				{
					if(timeTimer[client][tNade]==INVALID_HANDLE)
					{
						timeTimer[client][tNade] = CreateTimer(0.1, helpTimer, nadeId[client][tNade], TIMER_REPEAT);
					}
				}
				if(GetConVarInt(cvNadeSoundMode)==0)
				{
					EmitSoundToClient(client, SND_NADE_CONC_TIMER);
				}
				else
				{
					EmitSoundToAll(SND_NADE_CONC_TIMER, client);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action:Command_UnConc(client, args)
{
	if(GetConVarInt(cvConcEnabled)==1)
	{
		buttonDown[client] = false;
		new tHold[2] = { 0, -1 };
		for(new i=0;i<10;i++)
		{
			if(holding[client][i])
			{
				tHold[0]++;
				tHold[1] = i;
			}
		}
		if(GetConVarInt(cvConcDebug)==1)
		{ 
			PrintToServer("client %i, holding %i nades", client, tHold); 
		}
		if(tHold[0]==1)
		{
			ThrowNade(nadeId[client][tHold[1]]);
		}
	}
	return Plugin_Handled;
}

public Action:Command_ConcHelp(client, args)
{
	if(concHelp[client])
	{
		concHelp[client] = false;
	}
	else
	{
		concHelp[client] = true;
	}
	return Plugin_Handled;
}

public Action:Command_ConcTimer(client, args)
{
	if(GetConVarInt(cvConcEnabled)==1)
	{
		if(args>0)
		{
			new String:arg[32];
			GetCmdArg(1, arg, sizeof(arg));
			/*
			for(new i=0;i<strlen(arg);i++) 
			{
				if(!IsCharNumeric(arg[i])) 
				{
					ReplyToCommand(client, "Value must be an integer.");
					return Plugin_Handled;
				}
			}
			*/
			new Float:fArg = StringToFloat(arg);
			if(fArg < 3.0) 
			{ 
				ReplyToCommand(client, "Value must be 3.0 or higher"); 
				return Plugin_Handled;
			}
			personalTimer[client] = fArg;
		}
		else
		{
			personalTimer[client] = -1.0;
		}
	}
	return Plugin_Handled;
}

GetFreeNadeSlot(client)
{
	for(new i=0;i<10;i++)
	{
		if(nadeId[client][i] == -1)
		{
			return i;
		}
	}
	return -1;
}

FindNade(id)
{
	new value[2] = { -1, -1 };
	if(id > 0)
	{
		for(new i=0;i<MAXPLAYERS;i++)
		{
			for(new j=0;j<10;j++)
			{
				if(nadeId[i][j] == id)
				{
					value[0] = i;
					value[1] = j;
					return value;
				}
			}
		}
	}
	return value;
}

MakeNade2(client, type=0)
{
	new number = GetFreeNadeSlot(client);
	if(number > -1)
	{
		new String:model[255], String:skin[8];
		if(type == 0)
		{
			strcopy(model, sizeof(model), MDL_CONC);
		}
		
		
		nadeId[client][number] = CreateEntityByName("prop_physics");
		if(GetConVarInt(cvConcDebug)==1)
		{ 
			PrintToServer("Making Nade %i (%i) of type %i, for client %i", nadeId[client][number], number, type, client); 
		}
		nadeType[client][number] = type;
		
		if (IsValidEntity(nadeId[client][number]))
		{
			SetEntPropEnt(nadeId[client][number], Prop_Data, "m_hOwnerEntity", client);
			SetEntityModel(nadeId[client][number], model);
			Format(skin, sizeof(skin), "%d", GetClientTeam(client)-2);
			DispatchKeyValue(nadeId[client][number], "skin", skin);
			
			//DispatchKeyValue(iEnt,"model",szModel);
			DispatchKeyValue(nadeId[client][number],"Solid","6");
			
			DispatchKeyValue(nadeId[client][number],"physdamagescale","10000.0");
			DispatchKeyValue(nadeId[client][number],"minhealthdmg","0");
			//DispatchKeyValue(nadeId[client][number],"sethealth","500000");
			
			SetEntProp(nadeId[client][number], Prop_Send, "m_usSolidFlags", 12); // FSOLID_NOT_SOLID|FSOLID_TRIGGER
			//SetEntProp(nadeId[client][number], Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
			SetEntProp(nadeId[client][number], Prop_Send, "m_CollisionGroup", 1); // COLLISION_GROUP_DEBRIS 
			
			SetEntityMoveType(nadeId[client][number],MOVETYPE_NOCLIP);
			
			//test to fix bug where entity nr = -1
			new String:tName[32];
			Format(tName, sizeof(tName), "tf2nade%d", client);
			DispatchKeyValue(nadeId[client][number], "targetname", tName);
			AcceptEntityInput(nadeId[client][number], "DisableDamageForces");
			
			SDKHook(nadeId[client][number],SDKHook_OnTakeDamage,fOnTakeDamage);
			//SDKHook(nadeId[client][number], SDKHook_Think, OnThink);
			SDKHook(nadeId[client][number], SDKHook_VPhysicsUpdate, PhysUp);
			//Entity_SetMaxSpeed(nadeId[client][number], 3500.0);
			
			DispatchSpawn(nadeId[client][number]);
			
			
			//SetEntProp(iEnt,Prop_Data,"m_CollisionGroup",5); 
			//SetEntProp(iEnt,Prop_Data,"m_usSolidFlags",28);
			
			
			
			
			
			
			if(GetConVarInt(cvConcDebug)==1)
			{ 
				PrintToServer("Nade %i (%i) made of type %i, for client %i", nadeId[client][number], number, type, client); 
			}
			return number;
		}
	}
	return -1;
}

//public Action:fOnTakeDamage(iEnt,&iAttacker,&iInflictor,&Float:flDamage,&iDamageType) {
public Action:fOnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype, &weapon, Float:damageForce[3], Float:damagePosition[3])
{
	if(damagetype != DMG_CRUSH) return;
    
	static String:szAttacker[3];
	IntToString(attacker,szAttacker,sizeof(szAttacker));
	
	//PrintToChatAll("Prop touched %s",!attacker ? "world" : szAttacker);
	new nadeInfo[2]; nadeInfo = FindNade(victim);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new client = nadeInfo[0];
		new number = nadeInfo[1];
		if(IsValidEntity(nadeId[client][number]))
		{
			new Float:now = GetGameTime();
			new Float:delay = GetConVarFloat(cvConcBounceDelay);
			if(now - lastTime[client][number] > delay)
			{
				BounceConc2(victim, damagePosition);
			}
			lastTime[client][number] = now;
		}
		
	}
	
}

public PhysUp(ent)
{
	//PrintToChatAll("something");
	new nadeInfo[2]; nadeInfo = FindNade(ent);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new i = nadeInfo[0];
		new j = nadeInfo[1];
		
		//Saving last 2 origins to calculate speed (cos tf2 is fucked when it comes to finding speed from prop_physics)
		if(frameTimer[i][j]==GetConVarInt(cvFrameTimer))
		{
			new Float:absOri[3];
			Entity_GetAbsOrigin(ent, absOri);
		
			//frameTimer[i][j] = 
			
			lastOri[i][j][1][0] = lastOri[i][j][0][0];
			lastOri[i][j][1][1] = lastOri[i][j][0][1];
			lastOri[i][j][1][2] = lastOri[i][j][0][2];
			
			lastOri[i][j][0][0] = absOri[0];
			lastOri[i][j][0][1] = absOri[1];
			lastOri[i][j][0][2] = absOri[2];
			
			
			
			frameTimer[i][j] = 0;
		}
		frameTimer[i][j]++;
		
		
		//Timer for beeps
		/*
		if(lastTime2[i][j] != -1.0)
		{
			new Float:now = GetGameTime();
			new Float:tElapsed = lastTime2[i][j] - now;
			
			new Float:timerToUse;
			if(personalTimer[client] != -1.0) { timerToUse = personalTimer[client]; }
			else { timerToUse = GetConVarFloat(cvNadeTimer); }
			//timerToUse -= 1.0;
			
			new Float:diffr = timerToUse-nadeTime[client][number];
			
			
			//with 3.0timer, 3.0 = nobeep, cos command_conc -> makenade
			if(tElapsed >= 1.0 && diffr > 1.41)
			{
				//nadeTime[i][j] += tElapsed;
				nadeTime[i][j] += 1.0;
			}
			else if(tElapsed >= 0.1 && diffr <= 0.4)
			{
				//nadeTime[i][j] += tElapsed;
				nadeTime[i][j] += tempish;
			}
		}
		*/
	}	
	else
	{
		if(GetConVarInt(cvConcDebug)==1)
		{ 
			PrintToChatAll("INVALID SHIZZLE"); 
		}
	}
}


BounceConc2(entity, Float:damagePos[3])
{
	decl Float:vOrigin[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	
	new Float:vHeading[3]; SubtractVectors(damagePos, vOrigin, vHeading);
	new Float:vAngles[3]; GetVectorAngles(vHeading, vAngles);
	
	new Handle:trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);
		
	if(!TR_DidHit(trace))
	{
		CloseHandle(trace);
		return -1;
	}
		
	decl Float:vNormal[3];
	TR_GetPlaneNormal(trace, vNormal);
	//270 = flat, 90 = flat aswell.. but upside down
	//PrintToChatAll("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);
		
	CloseHandle(trace);
	
	
	new Float:dotProduct;
	new nadeInfo[2]; nadeInfo = FindNade(entity);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new client = nadeInfo[0];
		new number = nadeInfo[1];
		
		
		//PrintToChat(client, "lastOri[0] %.2f, %.2f, %.2f", lastOri[client][number][0], lastOri[client][number][1], lastOri[client][number][2]);
		//PrintToChat(client, "nowOri[3] %.2f, %.2f, %.2f", vOrigin[0], vOrigin[1], vOrigin[2]);
		
		
		
		
		new Float:vVec[3];
		//SubtractVectors(vOrigin, lastOri[client][number], vVec);
		SubtractVectors(lastOri[client][number][0], lastOri[client][number][1], vVec);
		new Float:ratio = 66.0/GetConVarFloat(cvFrameTimer);
		ScaleVector(vVec, ratio);
		new Float:len; len = GetVectorLength(vVec);
		
		
		if(len > 20.0)
		{
			//PrintToChat(client, "Impact: [%.2f, %.2f, %.2f] |%.2f|", vVec[0], vVec[1], vVec[2], len);
			dotProduct = GetVectorDotProduct(vNormal, vVec)*-1.0;
			
			ScaleVector(vNormal, dotProduct);
			ScaleVector(vNormal, 2.0);
				
			decl Float:vBounceVec[3];
			AddVectors(vVec, vNormal, vBounceVec);
			
			decl Float:vNewAngles[3];
			GetVectorAngles(vBounceVec, vNewAngles);
				
			//PrintToChat(client, "Result: [%.2f, %.2f, %.2f] |%.2f|", vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
			
			//groundresistance specific
			/*
			if(FloatCompare(vVec[0], vBounceVec[0]) == 0 && FloatCompare(vVec[1], vBounceVec[1]) == 0 && FloatCompare(vVec[2], vBounceVec[2]) != 0) { vBounceVec[2] *= 0.99; }
			else if(FloatCompare(vVec[0], vBounceVec[0]) == 0 && FloatCompare(vVec[1], vBounceVec[1]) != 0 && FloatCompare(vVec[2], vBounceVec[2]) == 0) { vBounceVec[1] *= 0.99; }
			else if(FloatCompare(vVec[0], vBounceVec[0]) != 0 && FloatCompare(vVec[1], vBounceVec[1]) == 0 && FloatCompare(vVec[2], vBounceVec[2]) == 0) { vBounceVec[0] *= 0.99; }
			*/
			//groundresistance global
			new Float:grRes = GetConVarFloat(cvNadeGroundRes);
			if(FloatCompare(vVec[0], vBounceVec[0]) != 0.0) vBounceVec[0] *= grRes;
			if(FloatCompare(vVec[1], vBounceVec[1]) != 0.0) vBounceVec[1] *= grRes;
			if(FloatCompare(vVec[2], vBounceVec[2]) != 0.0) vBounceVec[2] *= grRes;
			
			//PrintToServer("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
			//PrintToServer("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
				
			TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);
			frameTimer[client][number] = 0;
		}
	}
	
	return 1;
}

public bool:TEF_ExcludeEntity(entity, contentsMask, any:data)
{
	return (entity != data);
}

ThrowNade(id, bool:thrown = true)
{
	new nadeInfo[2]; nadeInfo = FindNade(id);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new client = nadeInfo[0];
		new number = nadeInfo[1];
		if(IsValidEntity(nadeId[client][number]))
		{
			// get position and angles
			new Float:startpt[3];
			GetClientEyePosition(client, startpt);
			new Float:angle[3];
			new Float:speed[3];
			new Float:playerspeed[3];
			
			angle[0] = GetRandomFloat(-180.0, 180.0);
			angle[1] = GetRandomFloat(-180.0, 180.0);
			angle[2] = GetRandomFloat(-180.0, 180.0);
			
			if(thrown)
			{
				holding[client][number] = false;
				GetClientEyeAngles(client, angle);
				
				new Float:angle2[3]; angle2 = CopyVector(angle);
				angle[1] += GetConVarFloat(cvNadeAngleCorrection);
				angle2[0] -= GetConVarFloat(cvNadeThrowAngle);
				GetAngleVectors(angle2, speed, NULL_VECTOR, NULL_VECTOR);
				//PrintToChat(client, "angles: [%.2f, %.2f, %.2f]", angle2[0], angle2[1], angle2[2]);
				//tempblock
				//speed[2]+=GetConVarFloat(cvNadeThrowAngle);
				
				
				//speed[0]*=GetConVarFloat(cvConcThrowSpeed); speed[1]*=GetConVarFloat(cvConcThrowSpeed); speed[2]*=GetConVarFloat(cvConcThrowSpeed);
				ScaleVector(speed, GetConVarFloat(cvNadeThrowSpeed));
				if(GetConVarInt(cvNadePhysics)>0)
				{
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerspeed);
					if(GetConVarInt(cvNadePhysics)==1)
					{
						for(new i=0;i<2;i++)
						{
							if(playerspeed[i] >= 0.0 && speed[i] < 0.0)
							{
								playerspeed[i] = 0.0;
							}
							else if(playerspeed[i] < 0.0 && speed[i] >= 0.0)
							{
								playerspeed[i] = 0.0;
							}
						}
						if(playerspeed[2] < 0.0 )
						{
							playerspeed[2] = 0.0;
						}
					}
					AddVectors(speed, playerspeed, speed);
				}
				new Float:sHeight = GetConVarFloat(cvNadeStartHeight);
				if(sHeight!=0.0) startpt[2] += sHeight;
				TeleportEntity(nadeId[client][number], startpt, angle, speed);
			}
			else
			{
				new Float:altstartpt[3];
				GetClientAbsOrigin(client, altstartpt);
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerspeed);
				ScaleVector(playerspeed, GetConVarFloat(cvNadeHHDisDecrease));
				
				new Float:pSpeedLen = GetVectorLength(playerspeed);
				if(pSpeedLen > 288.0) { pSpeedLen = 288.0/pSpeedLen; ScaleVector(playerspeed, pSpeedLen); }
				
				SubtractVectors(altstartpt, playerspeed, altstartpt);
				altstartpt[2] += GetConVarFloat(cvNadeHHHeight);
				TeleportEntity(nadeId[client][number], altstartpt, angle, NULL_VECTOR);
			}
			if(GetConVarFloat(cvNadeDifGrav)!=1.0)
			{
				SetEntityGravity(nadeId[client][number], GetConVarFloat(cvNadeDifGrav));
			}
			
			if(GetConVarInt(cvNadeTrail)==1)
			{
				new color[4];
				if(GetClientTeam(client)==2) //red
				{
					color = { 255, 10, 10, 255 };
				}
				else if(GetClientTeam(client)==3)
				{
					color = { 10, 10, 255, 255 };
				}
				else
				{
					color = { 10, 255, 10, 255 };
				}
				ShowTrail(nadeId[client][number], color);
			}
			EmitSoundToAll(SND_THROWNADE, client);
		}
	}
	else 
	{
		if(GetConVarInt(cvConcDebug)==1)
		{ 
			PrintToServer("info not found for concId %i", id); 
		}
	}
}

Float:CopyVector(Float:result[3])
{
	return result;
}

public Action:beepTimer(Handle:timer, any:concId)
{
	//getting client and nade number info
	new nadeInfo[2]; nadeInfo = FindNade(concId);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new client = nadeInfo[0];
		new number = nadeInfo[1];
		
		//getting max time for this clients nades (default/customized)
		new Float:timerToUse;
		if(personalTimer[client] != -1.0) { timerToUse = personalTimer[client]; }
		else { timerToUse = GetConVarFloat(cvNadeTimer); }
		timerToUse -= 1.0;
		
		new Float:diffr = timerToUse-nadeTime[client][number];
		//PrintToChat(client, "diffr = %.2f", diffr);
		if(diffr > 0.01)
		{
			//if holding make sound come from client pos, else from conc itself, unless sounds are off, then always only for client
			
			if(GetConVarInt(cvNadeSoundMode)==0)
			{
				if(diffr>0.41)
				{
					sEmitSound(client, client, false);
					//EmitSoundToClient(client, SND_NADE_CONC_TIMER);
				}
				else
				{
					sEmitSound(client, client, true);
					//EmitSoundToClient(client, SND_NADE_CONC_TIMER, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL|SND_CHANGEPITCH, 0.75, 120);
				}
			}
			else
			{
				if(holding[client][number]) 
				{
					if(diffr>0.41)
					{
						//EmitSoundToAll(SND_NADE_CONC_TIMER, client);
						sEmitSound(-1, client, false);
					}
					else
					{
						sEmitSound(-1, client, true);
						//EmitSoundToAll(SND_NADE_CONC_TIMER, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL|SND_CHANGEPITCH, 0.75, 120);
					}
				}
				else
				{
					if(diffr>0.41)
					{
						sEmitSound(-1, concId, false);
						//EmitSoundToAll(SND_NADE_CONC_TIMER, concId);
					}
					else
					{
						sEmitSound(-1, concId, true);
						//EmitSoundToAll(SND_NADE_CONC_TIMER, concId, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL|SND_CHANGEPITCH, 0.75, 120);
					}
				}
			}
			
			//make sure timer knows for when to set next beep
			//new Float:tempish = (timerToUse-1.0)-nadeTime[client][number];
			//PrintToChat(client, "%.2f", tempish);
			//timer has to leave 0.3, 0.2 and 0.1 for final beeps
			
			if(diffr > 1.41)
			{
				CreateTimer(1.0, beepTimer, concId);
				nadeTime[client][number] += 1.0;
				//PrintToChat(client, "1 sec delay");
			}
			else
			{
				new Float:tempish;
				if(diffr > 0.41) tempish = diffr - 0.4;
				else tempish = 0.4; //or 0.1 if other timer
				
				CreateTimer(tempish, beepTimer, concId);
				nadeTime[client][number] += tempish;
				
				//PrintToChat(client, "%.2f sec delay", tempish);
				/*
				if(tempish > 0.0 && tempish < 1.0)
				{
					
					CreateTimer(tempish, beepTimer, concId);
					nadeTime[client][number] += tempish;
				}
				else
				{
					CreateTimer(1.0, beepTimer, concId);
					nadeTime[client][number] += 1.0;
				}
				*/
			}
		}
		else
		{
			if(holding[client][number])
			{
				ThrowNade(concId, false);
				holding[client][number] = false;
				NadeExplode(concId, true);
			}
			else
			{
				NadeExplode(concId, false);
			}
			//CreateTimer(1.0, ExplodeTimer, 
		}
	}
	return Plugin_Handled;
}

sEmitSound(client = -1, locId, bool:highpitch)
{
	if(client > 0)
	{
		if(highpitch) EmitSoundToClient(client, SND_NADE_CONC_HIGHPITCH);
		else EmitSoundToClient(client, SND_NADE_CONC_TIMER);
	}
	else
	{
		if(highpitch) EmitSoundToAll(SND_NADE_CONC_HIGHPITCH, locId);
		else EmitSoundToAll(SND_NADE_CONC_TIMER, locId);
	}
}

public Action:delayTimer(Handle:timer, any:client)
{
	nadeDelay[client] = false;
	return Plugin_Handled;
}

public Action:helpTimer(Handle:timer, any:concId)
{
	//new client = FindConcOwner(concId);
	//new number = FindNr(client, concId);
	new nadeInfo[2]; nadeInfo = FindNade(concId);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new client = nadeInfo[0];
		new number = nadeInfo[1];
		helpCounter[client][number]++;
		new String:sTime[32], ln = 0;
		for(new i=0;i<helpCounter[client][number];i++)
		{
			if(i%10==0) { ln += Format(sTime[ln], 31-ln, "X"); }
			else { ln += Format(sTime[ln], 31-ln, "I"); }
		}
		SetHudTextParams(0.04, 0.47 - (0.05 * number), 1.0, 255, 10, 10, 255);
		if(holding[client][number]) { ShowSyncHudText(client, HudMsg[client][number], "H %s", sTime); }
		else { ShowSyncHudText(client, HudMsg[client][number], "   %s", sTime); }
	}
	else
	{
		if(GetConVarInt(cvConcDebug)==1)
		{ 
			PrintToServer("couldn't find info for concId %i", concId); 
		}
	}
}

NadeExplode(concId, bool:handHeld = false)
{
	new nadeInfo[2]; nadeInfo = FindNade(concId);
	if(nadeInfo[0] > -1 && nadeInfo[1] > -1)
	{
		new client = nadeInfo[0];
		new number = nadeInfo[1];
		
		//PrintToChat(client, "Fin");
		
		new Float:center[3];
		nadesUsed[client]--;
	
		GetEntPropVector(concId, Prop_Send, "m_vecOrigin", center);
		if(nadeType[client][number] == 0)
		{
			new Float:radius = GetConVarFloat(cvConcRadius);
			SetupConcBeams(center, radius);
			EmitSoundToAll(SND_NADE_CONC, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, center, NULL_VECTOR, false, 0.0);
			if(GetConVarInt(cvConcIgnore) == 1) { FindPlayersInRange(center, radius, 0, client, false, -1); }
			else { FindPlayersInRange(center, radius, 0, client, true, nadeId[client][number]); }
			new damage = 1;
			for (new j=1;j<=GetMaxClients();j++)
			{
				if(PlayersInRange[j]>0.0)
				{
					if(j==client || GetConVarInt(cvConcNoOtherPush)==0)
					{
						ConcPlayer(j, center, radius, client, handHeld);
						new String:tempString[32]; GetConVarString(cvNadeIcon, tempString, sizeof(tempString));
						DealDamage(j, damage, center, client, DMG_CRUSH, tempString);
					}
				}
			}
		}
		nadeTime[client][number] = -1.0;
		nadeType[client][number] = -1;
		nadeId[client][number] = -1;
		if(timeTimer[client][number] != INVALID_HANDLE) { CloseHandle(timeTimer[client][number]); timeTimer[client][number] = INVALID_HANDLE; }
		helpCounter[client][number] = -1;
		TeleportEntity(concId, holdingArea, NULL_VECTOR, NULL_VECTOR);
		RemoveEdict(concId);
		
		lastOri[client][number][0][0] = 0.0;
		lastOri[client][number][0][1] = 0.0;
		lastOri[client][number][0][2] = 0.0;
		lastOri[client][number][1][0] = 0.0;
		lastOri[client][number][1][1] = 0.0;
		lastOri[client][number][1][2] = 0.0;
		frameTimer[client][number] = 0;
	}
}

ConcPlayer(victim, Float:center[3], Float:radius, attacker, bool:hh)
{
	new Float:pSpd[3], Float:cPush[3], Float:pPos[3], Float:distance, Float:pointDist, Float:calcSpd, Float:baseSpd;
	GetClientAbsOrigin(victim, pPos); pPos[2] += GetConVarFloat(cvConcBaseHeight);
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", pSpd);
	distance = GetVectorDistance(pPos, center);
	SubtractVectors(pPos, center, cPush);
	NormalizeVector(cPush, cPush);
	pointDist = FloatDiv(distance, radius);
	if(hh) 
	{ 
		pointDist = pointDist*GetConVarFloat(cvConcHHBoost) + 0.25;
		if(pointDist > 1.0) { pointDist = 1.0; }
	}
	//if(concHelp[attacker] && attacker == victim) { PrintToChat(attacker, "Distance %f of 1.0", pointDist); }
	baseSpd = GetConVarFloat(cvConcBaseSpeed);
	if(GetConVarFloat(cvBlastDistanceMin) > pointDist) { pointDist = GetConVarFloat(cvBlastDistanceMin); }
	calcSpd = baseSpd*pointDist;
	//PrintToChat(victim, "Dist %f, calcSpd %f, pointDist %f", distance, calcSpd, pointDist);
	if(GetConVarInt(cvConcTest)==1)
	{
		calcSpd = ( (1.0/(baseSpd))*Pow(calcSpd, 2.0) )+(baseSpd*0.5); //pointdist 1 = 1450speed, 1.25 = 1959speed, 0.5 = 712.5, 0 = 475
	}
	else
	{
		calcSpd = -1.0*Cosine( (calcSpd / baseSpd) * 3.141592 ) * ( baseSpd - (800.0 / 3.0) ) + ( baseSpd + (800.0 / 3.0) );
	}
	//PrintToChat(victim, "pointDist: %f, calcSpeed %i", pointDist, RoundFloat(calcSpd));
	//PrintToChat(victim, "calcSpd after %f", calcSpd);
	//if(calcSpd < 0.5*baseSpd) { calcSpd = 0.5*baseSpd; } 
	ScaleVector(cPush, calcSpd);
	new bool:OnGround; if(GetEntityFlags(victim) & FL_ONGROUND){ OnGround = true; } else { OnGround = false; }
	if((hh && victim != attacker) || !hh)
	{
		if(pSpd[2] < 0.0 && cPush[2] > 0.0 && GetConVarInt(cvConcBounce)==1) { pSpd[2] = 0.0; }
	}
	//if(concHelp[attacker] && attacker == victim) { PrintToChat(attacker, "Spd[2] %f, push %f, %f, %f", pSpd[2], cPush[0], cPush[1], cPush[2]); }
	AddVectors(pSpd, cPush, pSpd);
	
	if(OnGround) { if(pSpd[2] < 800.0/3.0) { pSpd[2] = 800.0/3.0; } }
	//PrintToChat(victim, "Final: x %f, y %f, z %f", pSpd[0], pSpd[1], pSpd[2]);
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, pSpd);
}

IsClassAllowed(String:playerClass[16])
{
	if(GetConVarInt(cvConcEnabled)==1)
	{
		new String:sKeywords[64];
		GetConVarString(cvConcClass, sKeywords, 64);
		// = "jump_,rj_,quad_,conc_,cp_,ctf_";
		new String:sKeyword[16][32];
		new iKeywords = ExplodeString(sKeywords, ",", sKeyword, 16, 16);
		for(new i = 0; i < iKeywords; i++)
		{
			if(StrContains(playerClass, sKeyword[i], false) > -1)
			{ return true; }
		}
	}
	return false;
}

SetupConcBeams(Float:center[3], Float:radius)
{
	new beamcolor[4] = { 255, 255, 255, 255 };
	new Float:beamcenter[3]; beamcenter = center;
	new Float:height = (radius/2.0)/GetConVarFloat(cvConcRings);
	for(new f=0;f<GetConVarInt(cvConcRings);f++)
	{
		TE_SetupBeamRingPoint(beamcenter,2.0,radius,gRingModel,gRingModel,0,1,0.35,6.0,0.0,beamcolor,0,FBEAM_FADEOUT);
		TE_SendToAll(0.0);
		beamcenter[2] += height;
	}
}

ShowTrail(nade, color[4])
{
	TE_SetupBeamFollow(nade, gRingModel, 0, Float:1.0, Float:10.0, Float:10.0, 5, color);
	TE_SendToAll();
}

DealDamage(victim, damage, Float:loc[3],attacker=0,dmg_type=DMG_GENERIC,String:weapon[]="")
{
	if(victim>0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage>0)
	{
		new String:dmg_str[16];
		IntToString(damage,dmg_str,16);
		new String:dmg_type_str[32];
		IntToString(dmg_type,dmg_type_str,32);
		//PrintToChat(victim, "victim %i is valid and hit by attacker %i", victim, attacker);
		new pointHurt=CreateEntityByName("point_hurt");
		if(pointHurt)
		{
			//new Float:vicOri[3];
			//GetClientAbsOrigin(victim, vicOri);
			TeleportEntity(pointHurt, loc, NULL_VECTOR, NULL_VECTOR);
			//Format(tName, sizeof(tName), "hurtme%d", victim);
			DispatchKeyValue(victim,"targetname","hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","hurtme");
			DispatchKeyValue(pointHurt,"Damage",dmg_str);
			DispatchKeyValue(pointHurt,"DamageType",dmg_type_str);
			if(!StrEqual(weapon,""))
			{
				//PrintToChat(victim, "weaponname = %s", weapon);
				DispatchKeyValue(pointHurt,"classname",weapon);
			}
			DispatchSpawn(pointHurt);
			
			AcceptEntityInput(pointHurt,"Hurt",(attacker>0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			//Format(tName, sizeof(tName), "donthurtme%d", victim);
			DispatchKeyValue(victim,"targetname","donthurtme");
			//TeleportEntity(pointHurt[victim], gHoldingArea, NULL_VECTOR, NULL_VECTOR);
			//CreateTimer(0.01, TPHurt, victim);
			RemoveEdict(pointHurt);
		}
	}
}

AddFolderToDownloadTable(const String:Directory[], bool:recursive=false) 
{
	decl String:FileName[64], String:Path[512];
	new Handle:Dir = OpenDirectory(Directory), FileType:Type;
	while(ReadDirEntry(Dir, FileName, sizeof(FileName), Type))     
	{
		if(Type == FileType_Directory && recursive)         
		{           
			FormatEx(Path, sizeof(Path), "%s/%s", Directory, FileName);
			AddFolderToDownloadTable(Path);
			continue;
			
		}                 
		if (Type != FileType_File) continue;
		FormatEx(Path, sizeof(Path), "%s/%s", Directory, FileName);
		AddFileToDownloadsTable(Path);
	}
	return;	
}

FindPlayersInRange(Float:location[3], Float:radius, team, self, bool:trace, donthit)
{
	new Float:rsquare = radius*radius;
	new Float:orig[3];
	new Float:distance;
	new Handle:tr;
	new j;
	new maxplayers = GetMaxClients();
	//if(GetConVarInt(ff)==1){ team = 0; }
	for (j=1;j<=maxplayers;j++)
	{
		PlayersInRange[j] = 0.0;
		if (IsClientInGame(j))
		{
			if (IsPlayerAlive(j))
			{
				if ( (team>1 && GetClientTeam(j)==team) || team==0 || j==self)
				{
					GetClientAbsOrigin(j, orig);
					orig[0]-=location[0];
					orig[1]-=location[1];
					orig[2]-=location[2];
					orig[0]*=orig[0];
					orig[1]*=orig[1];
					orig[2]*=orig[2];
					distance = orig[0]+orig[1]+orig[2];
					if (distance < rsquare)
					{
						if (trace)
						{
							GetClientEyePosition(j, orig);
							tr = TR_TraceRayFilterEx(location, orig, MASK_SOLID, RayType_EndPoint, TraceRayHitPlayers, donthit);
							if (tr!=INVALID_HANDLE)
							{
								if (TR_GetFraction(tr)>0.98)
								{
									PlayersInRange[j] = SquareRoot(distance)/radius;
								}
								CloseHandle(tr);
							}
							
						}
						else
						{
							PlayersInRange[j] = SquareRoot(distance)/radius;
						}
					}
				}
			}
		}
	}
}

public bool:TraceRayHitPlayers(entity, mask, any:startent)
{
	if(entity == startent)
	{
		return false;
	}
	if (entity <= GetMaxClients() && entity > 0)
	{
		return true;
	}
	return false; 
}

public Action:DeleteParticles(Handle:timer, any:particle)
{
	if (IsValidEntity(particle))
	{
		new String:classname[128];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false))
		{
			RemoveEdict(particle);
		}
		else
		{
			LogError("DeleteParticles: not removing entity - not a particle '%s'", classname);
		}
	}
}

public ShowParticle(Float:pos[3], String:particlename[], Float:time)
{
	new particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle))
	{
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
	else
	{
		LogError("ShowParticle: could not create info_particle_system");
	}	
}