#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

#define PLUGIN_VERSION "1.3.0"

public Plugin myinfo = {
	name = "Concussion Grenade",
	author = "CrancK",
	description = "gives specified classes the concussion grenade from other tf's",
	version = PLUGIN_VERSION,
	url = ""
};

#define DMG_TIMEBASED (DMG_PARALYZE | DMG_NERVEGAS | DMG_POISON | DMG_RADIATION | DMG_DROWNRECOVER | DMG_ACID | DMG_SLOWBURN)
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

ConVar
	cvConcEnabled
	, cvConcClass
	, cvConcRadius
	, cvConcMax
	, cvNadeDelay
	, cvNadeTimer
	, cvNadePhysics
	, cvNadeDifGrav
	, cvNadeTrail
	, cvNadeSoundMode
	, cvNadeThrowSpeed
	, cvNadeThrowAngle
	, cvConcIgnore
	, cvConcNoOtherPush
	, cvConcRings
	, cvConcBaseHeight
	, cvConcBaseSpeed
	, cvNadeIcon
	, cvNadeHHHeight
	, cvNadeHHDisDecrease
	, cvBlastDistanceMin
	, cvConcBounce
	, cvConcHHBoost
	, cvNadeAngleCorrection
	, cvNadeWaitPeriod
	, cvConcTest
	, cvConcBounceDelay
	, cvFrameTimer
	, cvNadeGroundRes
	, cvNadeStartHeight
	, cvConcDebug;

int
	gRingModel
	, nadesUsed[MAXPLAYERS]
	, concToUse[MAXPLAYERS]
	, nadeId[MAXPLAYERS][10]
	, realStart
	, nadeType[MAXPLAYERS][10]
	, helpCounter[MAXPLAYERS][10]
	, frameTimer[MAXPLAYERS][10];
bool
	holding[MAXPLAYERS][10]
	, nadeDelay[MAXPLAYERS]
	, buttonDown[MAXPLAYERS]
	//, concHelp[MAXPLAYERS]
	, canThrow
	, waitOver;
float
	nadeTime[MAXPLAYERS][10]
	, PlayersInRange[MAXPLAYERS]
	, holdingArea[3] = { -10000.0, ... }
	, personalTimer[MAXPLAYERS]
	, lastTime[MAXPLAYERS][10]
	, lastTime2[MAXPLAYERS][10]
	, lastOri[MAXPLAYERS][10][2][3];
Handle
	HudMsg[MAXPLAYERS][10]
	, timeTimer[MAXPLAYERS][10];




public void OnPluginStart() {
	CreateConVar("sm_conc_version", PLUGIN_VERSION, "Conc Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvConcEnabled = CreateConVar("sm_nade_enabled", "1", "Enables the plugin", 0);
	cvNadeWaitPeriod = CreateConVar("sm_nade_waitperiod", "0", "Reccomended if you have setuptime");
	cvConcClass = CreateConVar("sm_conc_class", "scout,medic", "Which classes are able to use the conc command", 0);
	cvConcRadius = CreateConVar("sm_conc_radius", "288.0", "Radius of conc blast", 0);
	cvConcMax = CreateConVar("sm_conc_max", "4", "How many concs a player can have spawned at the same time", 0);
	cvNadeDelay = CreateConVar("sm_nade_delay", "0.55", "How long a player has to wait before throwing another conc", 0);
	cvNadeTimer = CreateConVar("sm_nade_timer", "3.0", "How many second to wait until conc explodes", 0);
	cvNadePhysics = CreateConVar("sm_nade_physics", "0", "Throwing physics, 0 = sm_conc_throwspeed, 1 = sm_conc_throwspeed+ownspeed, 2 = mix", 0);
	cvNadeDifGrav = CreateConVar("sm_nade_difgrav", "1.75", "Since prop_physics don't use the same physics as a player, this is needed to give it the same terminal velocity", 0);
	cvNadeTrail = CreateConVar("sm_nade_trail", "1", "Enables a trail following the conc", 0);
	cvNadeSoundMode = CreateConVar("sm_nade_sounds", "1", "0 = sounds only for client throwing them, 1 = sounds audible for everyone", 0);
	cvNadeThrowSpeed = CreateConVar("sm_nade_throwspeed", "625.0", "Speed at which concs are thrown", 0);
	cvNadeThrowAngle = CreateConVar("sm_nade_throwangle", "20.0", "Positive aims higher then crosshair, negative lower", 0);
	cvConcIgnore = CreateConVar("sm_conc_ignorewalls", "1", "Enables the conc's explosion to push people through walls", 0);
	cvConcNoOtherPush = CreateConVar("sm_conc_ignoreothers", "1", "Enables the conc's to only push the person that threw it", 0);
	cvConcRings = CreateConVar("sm_conc_rings", "10.0", "Sets how many rings the conc explosion has", 0);
	cvConcBaseHeight = CreateConVar("sm_nade_baseheight", "48.0", "Correction for how high the player is when exploding, for making sure it pushes ppl off ground", 0);
	cvConcBaseSpeed = CreateConVar("sm_conc_basespeed", "950.0", "Base value for conc speed calculations", 0);
	cvNadeIcon = CreateConVar("sm_nade_killicon", "tf_projectile_rocket", "kill icon for concs", 0);
	cvNadeHHHeight = CreateConVar("sm_nade_hhheight", "24.0", "How high a nade should be spawned relative to feet on a handheld(feet = 0.0)", 0);
	cvNadeHHDisDecrease = CreateConVar("sm_nade_hhdisdec", "0.175", "This value*playerspeed = distance from you and nade on a handheld", 0);
	cvConcBounce = CreateConVar("sm_conc_bounce", "1", "Insures a conc has the power to push someone back up, no matter how fast he's falling", 0);
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
	RegConsoleCmd("-conc", Command_UnConc);
	RegConsoleCmd("sm_conchelp", Command_ConcHelp);
	RegConsoleCmd("sm_conctimer", Command_ConcTimer);
	HookEvent("teamplay_restart_round", EventRestartRound);
	HookEvent("player_death", EventPlayerDeath, EventHookMode_Pre);
	HookEvent("teamplay_round_start", MainEvents);
	HookEvent("teamplay_round_active", MainEvents);
	HookEvent("teamplay_round_stalemate", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("teamplay_round_win", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("teamplay_game_over", RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("player_changeclass", EventPlayerChangeClass);
	for (int i = 1; i <= MaxClients; i++) {
		personalTimer[i] = -1.0;
		for (int j = 0; j < 10; j++) {
			//HudMsg[i][j] = CreateHudSynchronizer();
			lastTime[i][j] = 0.0;
			lastTime2[i][j] = -1.0;
		}
	}
}

public void OnMapStart() {
	
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
	
	canThrow = waitOver = false;
	for (int i = 1; i <= MaxClients; i++) {
		
		nadesUsed[i] = 0;
		concToUse[i] = -1;
		nadeDelay[i] = buttonDown[i] = false;
		
		for (int j = 0; j < 10; j++) {
			nadeId[i][j] = nadeType[i][j] = helpCounter[i][j] = -1;
			nadeTime[i][j] = lastTime2[i][j] = -1.0;
			holding[i][j] = false;
			timeTimer[i][j] = null;
			lastTime[i][j] = 0.0;
			
			for (int k = 0; k <= 2; k++) {
				lastOri[i][j][0][k] = lastOri[i][j][1][k] = 0.0;
			}

			frameTimer[i][j] = 0;
		}
	}
	
	
}

public void OnMapEnd() {
	canThrow = waitOver = false;
	for (int i = 1; i <= MaxClients; i++) {
		nadesUsed[i] = 0;
		concToUse[i] = -1;
		nadeDelay[i] = buttonDown[i] = false;
		personalTimer[i] = -1.0;
		for (int j = 0; j < 10; j++) {
			nadeId[i][j] = nadeType[i][j] = -1;
			nadeTime[i][j] = -1.0;
			holding[i][j] = false;
			delete timeTimer[i][j];
			helpCounter[i][j] = -1;
		}
	}
}

public void OnClientPostAdminCheck(int client) {
	for (int i = 0; i < 10; i++) {
		if (nadeId[client][i] != -1 && IsValidEntity(nadeId[client][i])) {
			RemoveEdict(nadeId[client][i]);
			nadeId[client][i] = -1;
		}
		else if (nadeId[client][i] != -1) {
			nadeId[client][i] = -1;
		}
		nadeTime[client][i] = -1.0;
		holding[client][i] = false;
		nadeType[client][i] = helpCounter[client][i] = -1;
		delete timeTimer[client][i];
	}
	personalTimer[client] = -1.0;
	nadeDelay[client] = buttonDown[client] = false;
	concToUse[client] = -1;
	nadesUsed[client] = 0;
	//SDKHook(client, SDKHook_PreThink, OnPreThink);
}

public void OnClientDisconnect(int client) {
	for (int i = 0; i < 10; i++) {
		if (nadeId[client][i] != -1 && IsValidEntity(nadeId[client][i])) {
			RemoveEdict(nadeId[client][i]);
			nadeId[client][i] = -1;
		}
		else if (nadeId[client][i] != -1) {
			nadeId[client][i] = -1;
		}
		nadeTime[client][i] = -1.0;
		holding[client][i] = false;
		nadeType[client][i] = -1;
		delete timeTimer[client][i];
		helpCounter[client][i] = -1;
	}
	nadeDelay[client] = buttonDown[client] = false;
	concToUse[client] = -1;
	nadesUsed[client] = 0;
	personalTimer[client] = -1.0;
}

public Action EventRestartRound(Event event, const char[] name, bool dontBroadcast) {
	if (cvConcEnabled.IntValue == 1 && cvNadeWaitPeriod.IntValue == 1) {
		waitOver = true;
	}
}

public Action EventPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client;
	client = GetClientOfUserId(event.GetInt("userid"));
	int tClass = view_as <int>(TF2_GetPlayerClass(client));
	char classString[16];
	switch(tClass) {
		case 1:	{
			Format(classString, sizeof(classString), "scout");
		}
		case 2: {
			Format(classString, sizeof(classString), "sniper");
		}
		case 3: {
			Format(classString, sizeof(classString), "soldier");
		}
		case 4: {
			Format(classString, sizeof(classString), "demoman");
		}
		case 5: {
			Format(classString, sizeof(classString), "medic");
		}
		case 6: {
			Format(classString, sizeof(classString), "heavy");
		}
		case 7: {
			Format(classString, sizeof(classString), "pyro");
		}
		case 8: {
			Format(classString, sizeof(classString), "spy");
		}
		case 9: {
			Format(classString, sizeof(classString), "engineer");
		}
	}
	if (IsClassAllowed(classString)) {
		for (int i = 0; i < 10; i++) {
			if (holding[client][i]) {
				ThrowNade(nadeId[client][i], false);
			}
		}
		/*
		while (!holding[client][nr] && nr < cvConcMax.IntValue) {
			nr++;
		}
		if (nr < cvConcMax.IntValue) {
			ThrowNade(client, false);
		}
		*/
	}
	else if (IsClassAllowed(classString)) {
		for (int i = 0; i < 10; i++) {
			if (holding[client][i]) {
				ThrowNade(nadeId[client][i], false);
			}
		}
		/*
		while (!holding[client][nr] && nr < cvFragMax.IntValue) {
			nr++;
		}
		if (nr < cvFragMax.IntValue) {
			ThrowNade(client, false);
		}
		*/
	}
}

//fix for changing class -> removing concs so people cant cheat 
public Action EventPlayerChangeClass(Event event, const char[] name, bool dontBroadcast) {
	int
		client = GetClientOfUserId(event.GetInt("userid"))
		, tClass = view_as <int>(TF2_GetPlayerClass(client));
	char classString[16];
	switch(tClass) {
		case 1:	{
			Format(classString, sizeof(classString), "scout");
		}
		case 2: {
			Format(classString, sizeof(classString), "sniper");
		}
		case 3: {
			Format(classString, sizeof(classString), "soldier");
		}
		case 4: {
			Format(classString, sizeof(classString), "demoman");
		}
		case 5: {
			Format(classString, sizeof(classString), "medic");
		}
		case 6: {
			Format(classString, sizeof(classString), "heavy");
		}
		case 7: {
			Format(classString, sizeof(classString), "pyro");
		}
		case 8: {
			Format(classString, sizeof(classString), "spy");
		}
		case 9: {
			Format(classString, sizeof(classString), "engineer");
		}
	}
	if (!IsClassAllowed(classString)) {
		for (int i = 0; i < 10; i++) {
			if (nadeId[client][i] != -1 && IsValidEntity(nadeId[client][i])) {
				RemoveEdict(nadeId[client][i]);
				nadeId[client][i] = -1;
			}
			else if (nadeId[client][i] != -1) {
				nadeId[client][i] = -1;
			}
			nadeTime[client][i] = -1.0;
			holding[client][i] = false;
			nadeType[client][i] = helpCounter[client][i] = -1;
			delete timeTimer[client][i];
		}
		nadeDelay[client] = buttonDown[client] =  false;
		//concHelp[client] = false;
		concToUse[client] = -1;
		nadesUsed[client] = 0;
		//personalTimer[client] = -1.0;
	}
}

public Action MainEvents(Event event, const char[] name, bool dontBroadcast) {
	if (waitOver && realStart%2 == 1 && cvNadeWaitPeriod.IntValue == 1) {
		if (StrEqual(name, "teamplay_round_start")) {
			canThrow = false;
		}
		else if (StrEqual(name, "teamplay_round_active")) {
			realStart++;
			canThrow = true;
		}
	}
	else if (cvNadeWaitPeriod.IntValue == 1) {
		if (StrEqual(name, "teamplay_round_start")) {
			//PrintToChatAll("teamplay_round_start && !waitover");
			//PrintToServer("teamplay_round_start && !waitover");
			canThrow = false;
		}
		else if (StrEqual(name, "teamplay_round_active")) {
			canThrow = false;
			realStart++;
		}
	}
	else {
		canThrow = waitOver = true;
	}
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	//PrintToChatAll("EventRoundEnd");
	//PrintToServer("EventRoundEnd");
	if (StrEqual(name, "teamplay_game_over")) {
		waitOver = canThrow = false;
		realStart = 0;
	}
	canThrow = false;
	realStart = 1;
	//waitOver = false;
}

public void OnEntityDestroyed(int ent) {
	if (cvConcEnabled.IntValue == 1) {
		if (IsValidEntity(ent)) {
			int nadeInfo[2];
			nadeInfo = FindNade(ent);
			if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
				int
					client = nadeInfo[0]
					, number = nadeInfo[1];

				nadeTime[client][number] = -2.0;
				nadeType[client][number] = nadeId[client][number] = helpCounter[client][number] = -1;
				delete timeTimer[client][number];
				nadesUsed[client]--;
			}
		}
	}
}

public Action Command_Conc(int client, int args) {
	if (cvConcEnabled.IntValue == 1 && canThrow) {
		int tClass = view_as <int>(TF2_GetPlayerClass(client));
		char classString[16];
		switch(tClass) {
			case 1:	{
				Format(classString, sizeof(classString), "scout");
			}
			case 2: {
				Format(classString, sizeof(classString), "sniper");
			}
			case 3: {
				Format(classString, sizeof(classString), "soldier");
			}
			case 4: {
				Format(classString, sizeof(classString), "demoman");
			}
			case 5: {
				Format(classString, sizeof(classString), "medic");
			}
			case 6: {
				Format(classString, sizeof(classString), "heavy");
			}
			case 7: {
				Format(classString, sizeof(classString), "pyro");
			}
			case 8: {
				Format(classString, sizeof(classString), "spy");
			}
			case 9: {
				Format(classString, sizeof(classString), "engineer");
			}
		}
		if (!IsPlayerAlive(client) || IsFakeClient(client) || IsClientObserver(client) || nadeDelay[client] || !IsClassAllowed(classString) || buttonDown[client]) {
			return Plugin_Handled;
		}
		for (int i = 0; i < 10; i++) {
			if (holding[client][i] == true) {
				return Plugin_Handled;
			}
		}
		if (nadesUsed[client] < cvConcMax.IntValue) {
			//new tNade = MakeNade(client);
			int tNade = MakeNade2(client);
			if (tNade > -1) {
				holding[client][tNade] = nadeDelay[client] = buttonDown[client] = true;
				nadesUsed[client]++;
				nadeTime[client][tNade] = 0.0;
				CreateTimer(1.0, beepTimer, nadeId[client][tNade]);
				//lastTime2[client][number] = GetGameTime();
				CreateTimer(cvNadeDelay.FloatValue, delayTimer, client);
				//if (concHelp[client]) {
				//	if (timeTimer[client][tNade] == null) {
				//		timeTimer[client][tNade] = CreateTimer(0.1, helpTimer, nadeId[client][tNade], TIMER_REPEAT);
				//	}
				//}
				if (cvNadeSoundMode.IntValue == 0) {
					EmitSoundToClient(client, SND_NADE_CONC_TIMER);
				}
				else {
					EmitSoundToAll(SND_NADE_CONC_TIMER, client);
				}
			}
		}
	}
	return Plugin_Handled;
}

public Action Command_UnConc(int client, int args) {
	if (cvConcEnabled.IntValue == 1) {
		buttonDown[client] = false;
		int tHold[2] = { 0, -1 };
		for (int i = 0; i < 10; i++) {
			if (holding[client][i]) {
				tHold[0]++;
				tHold[1] = i;
			}
		}
		if (cvConcDebug.IntValue == 1) { 
			PrintToServer("client %i, holding %i nades", client, tHold); 
		}
		if (tHold[0] == 1) {
			ThrowNade(nadeId[client][tHold[1]]);
		}
	}
	return Plugin_Handled;
}

public Action Command_ConcHelp(int client, int args) {
	ReplyToCommand(client, "Feature disabled because it's inefficient coding-wise and not even very helpful.");
	//if (concHelp[client]) {
	//	concHelp[client] = false;
	//}
	//else {
	//	concHelp[client] = true;
	//}
	return Plugin_Handled;
}

public Action Command_ConcTimer(int client, int args) {
	if (cvConcEnabled.IntValue == 1) {
		if (args > 0) {
			char arg[32];
			GetCmdArg(1, arg, sizeof(arg));
			/*
			for (int i = 0; i < strlen(arg); i++) {
				if (!IsCharNumeric(arg[i])) {
					ReplyToCommand(client, "Value must be an integer.");
					return Plugin_Handled;
				}
			}
			*/
			float fArg = StringToFloat(arg);
			if (fArg < 3.0) { 
				ReplyToCommand(client, "Value must be 3.0 or higher"); 
				return Plugin_Handled;
			}
			personalTimer[client] = fArg;
		}
		else {
			personalTimer[client] = -1.0;
		}
	}
	return Plugin_Handled;
}

int GetFreeNadeSlot(int client) {
	for (int i = 0; i < 10; i++) {
		if (nadeId[client][i] == -1) {
			return i;
		}
	}
	return -1;
}

int FindNade(int id) {
	int value[2] = { -1, -1 };
	if (id > 0) {
		for (int i = 1; i <= MaxClients; i++) {
			for (int j = 0; j < 10; j++) {
				if (nadeId[i][j] == id) {
					value[0] = i;
					value[1] = j;
					return value;
				}
			}
		}
	}
	return value;
}

int MakeNade2(int client, int type = 0) {
	int number = GetFreeNadeSlot(client);
	if (number > -1) {
		char
			model[255]
			, skin[8];
		if (type == 0) {
			strcopy(model, sizeof(model), MDL_CONC);
		}
		
		
		nadeId[client][number] = CreateEntityByName("prop_physics");
		if (cvConcDebug.IntValue == 1) { 
			PrintToServer("Making Nade %i (%i) of type %i, for client %i", nadeId[client][number], number, type, client); 
		}
		nadeType[client][number] = type;
		
		if (IsValidEntity(nadeId[client][number])) {
			SetEntPropEnt(nadeId[client][number], Prop_Data, "m_hOwnerEntity", client);
			SetEntityModel(nadeId[client][number], model);
			Format(skin, sizeof(skin), "%d", GetClientTeam(client)-2);
			DispatchKeyValue(nadeId[client][number], "skin", skin);
			
			//DispatchKeyValue(iEnt,"model", szModel);
			DispatchKeyValue(nadeId[client][number],"Solid","6");
			
			DispatchKeyValue(nadeId[client][number],"physdamagescale","10000.0");
			DispatchKeyValue(nadeId[client][number],"minhealthdmg","0");
			//DispatchKeyValue(nadeId[client][number],"sethealth","500000");
			
			// FSOLID_NOT_SOLID|FSOLID_TRIGGER
			SetEntProp(nadeId[client][number], Prop_Send, "m_usSolidFlags", 12); 

			//SetEntProp(nadeId[client][number], Prop_Data, "m_nSolidType", 6); // SOLID_VPHYSICS
			// COLLISION_GROUP_DEBRIS 
			SetEntProp(nadeId[client][number], Prop_Send, "m_CollisionGroup", 1); 

			
			SetEntityMoveType(nadeId[client][number], MOVETYPE_NOCLIP);
			
			//test to fix bug where entity nr = -1
			char tName[32];
			Format(tName, sizeof(tName), "tf2nade%d", client);
			DispatchKeyValue(nadeId[client][number], "targetname", tName);
			AcceptEntityInput(nadeId[client][number], "DisableDamageForces");
			
			SDKHook(nadeId[client][number], SDKHook_OnTakeDamage, fOnTakeDamage);
			//SDKHook(nadeId[client][number], SDKHook_Think, OnThink);
			SDKHook(nadeId[client][number], SDKHook_VPhysicsUpdate, PhysUp);
			//Entity_SetMaxSpeed(nadeId[client][number], 3500.0);
			
			DispatchSpawn(nadeId[client][number]);
			
			
			//SetEntProp(iEnt, Prop_Data,"m_CollisionGroup", 5); 
			//SetEntProp(iEnt, Prop_Data,"m_usSolidFlags", 28);
			
			
			
			
			
			
			if (cvConcDebug.IntValue == 1) { 
				PrintToServer("Nade %i (%i) made of type %i, for client %i", nadeId[client][number], number, type, client); 
			}
			return number;
		}
	}
	return -1;
}

//public Action fOnTakeDamage(iEnt,&iAttacker,&iInflictor,&float:flDamage,&iDamageType) {
public Action fOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (damagetype != DMG_CRUSH) {
		return;
	}
    
	static char szAttacker[3];
	IntToString(attacker, szAttacker, sizeof(szAttacker));
	
	//PrintToChatAll("Prop touched %s",!attacker ? "world" : szAttacker);
	int nadeInfo[2];
	nadeInfo = FindNade(victim);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int client = nadeInfo[0];
		int number = nadeInfo[1];
		if (IsValidEntity(nadeId[client][number])) {
			float now = GetGameTime();
			float delay = cvConcBounceDelay.FloatValue;
			if (now - lastTime[client][number] > delay) {
				BounceConc2(victim, damagePosition);
			}
			lastTime[client][number] = now;
		}
		
	}
	
}

public void PhysUp(int ent) {
	//PrintToChatAll("something");
	int nadeInfo[2];
	nadeInfo = FindNade(ent);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int i = nadeInfo[0];
		int j = nadeInfo[1];
		
		//Saving last 2 origins to calculate speed (cos tf2 is fucked when it comes to finding speed from prop_physics)
		if (frameTimer[i][j] == cvFrameTimer.IntValue) {
			float absOri[3];
			Entity_GetAbsOrigin(ent, absOri);
		
			//frameTimer[i][j] = 
			for (int k = 0; k <= 2; k++) {
				lastOri[i][j][1][k] = lastOri[i][j][0][k];
				lastOri[i][j][0][k] = absOri[k];
			}
			
			frameTimer[i][j] = 0;
		}
		frameTimer[i][j]++;
		
		
		//Timer for beeps
		/*
		if (lastTime2[i][j] != -1.0) {
			float now = GetGameTime();
			float tElapsed = lastTime2[i][j] - now;
			
			float timerToUse;
			if (personalTimer[client] != -1.0) {
				timerToUse = personalTimer[client];
			}
			else { timerToUse = cvNadeTimer.FloatValue;
			}
			//timerToUse -= 1.0;
			
			float diffr = timerToUse-nadeTime[client][number];
			
			
			//with 3.0timer, 3.0 = nobeep, cos command_conc -> makenade
			if (tElapsed >= 1.0 && diffr > 1.41) {
				//nadeTime[i][j] += tElapsed;
				nadeTime[i][j] += 1.0;
			}
			else if (tElapsed >= 0.1 && diffr <= 0.4) {
				//nadeTime[i][j] += tElapsed;
				nadeTime[i][j] += tempish;
			}
		}
		*/
	}	
	else {
		if (cvConcDebug.IntValue == 1) { 
			PrintToChatAll("INVALID SHIZZLE"); 
		}
	}
}


int BounceConc2(int entity, float damagePos[3]) {
	float
		vOrigin[3]
		, vHeading[3]
		, vAngles[3]
		, vNormal[3]
		, dotProduct;

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	SubtractVectors(damagePos, vOrigin, vHeading);
	GetVectorAngles(vHeading, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);
		
	if (!TR_DidHit(trace)) {
		delete trace;
		return -1;
	}

	TR_GetPlaneNormal(trace, vNormal);
	//270 = flat, 90 = flat aswell.. but upside down
	//PrintToChatAll("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);
		
	delete trace;
	
	int nadeInfo[2];
	nadeInfo = FindNade(entity);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int
			client = nadeInfo[0]
			, number = nadeInfo[1];
		float
			vVec[3];
		
		//PrintToChat(client, "lastOri[0] %.2f, %.2f, %.2f", lastOri[client][number][0], lastOri[client][number][1], lastOri[client][number][2]);
		//PrintToChat(client, "nowOri[3] %.2f, %.2f, %.2f", vOrigin[0], vOrigin[1], vOrigin[2]);
		
		
		//SubtractVectors(vOrigin, lastOri[client][number], vVec);
		SubtractVectors(lastOri[client][number][0], lastOri[client][number][1], vVec);
		float ratio = 66.0/cvFrameTimer.FloatValue;
		ScaleVector(vVec, ratio);
		float len = GetVectorLength(vVec);
		
		if (len > 20.0) {
			float
				vBounceVec[3]
				, vNewAngles[3];
			//PrintToChat(client, "Impact: [%.2f, %.2f, %.2f] |%.2f|", vVec[0], vVec[1], vVec[2], len);
			dotProduct = GetVectorDotProduct(vNormal, vVec)*-1.0;
			
			ScaleVector(vNormal, dotProduct);
			ScaleVector(vNormal, 2.0);
			AddVectors(vVec, vNormal, vBounceVec);
			GetVectorAngles(vBounceVec, vNewAngles);
				
			//PrintToChat(client, "Result: [%.2f, %.2f, %.2f] |%.2f|", vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
			
			//groundresistance specific
			/*
			if (FloatCompare(vVec[0], vBounceVec[0]) == 0 && FloatCompare(vVec[1], vBounceVec[1]) == 0 && FloatCompare(vVec[2], vBounceVec[2]) != 0) {
				vBounceVec[2] *= 0.99;
			}
			else if (FloatCompare(vVec[0], vBounceVec[0]) == 0 && FloatCompare(vVec[1], vBounceVec[1]) != 0 && FloatCompare(vVec[2], vBounceVec[2]) == 0) {
				vBounceVec[1] *= 0.99;
			}
			else if (FloatCompare(vVec[0], vBounceVec[0]) != 0 && FloatCompare(vVec[1], vBounceVec[1]) == 0 && FloatCompare(vVec[2], vBounceVec[2]) == 0) {
				vBounceVec[0] *= 0.99;
			}
			*/
			//groundresistance global
			float grRes = cvNadeGroundRes.FloatValue;
			for (int i = 0; i <= 2; i++) {
				if (FloatCompare(vVec[i], vBounceVec[i]) != 0.0) {
					vBounceVec[i] *= grRes;
				}
			}
			//PrintToServer("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
			//PrintToServer("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
				
			TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);
			frameTimer[client][number] = 0;
		}
	}
	
	return 1;
}

public bool TEF_ExcludeEntity(int entity, int contentsMask, any data) {
	return (entity != data);
}

void ThrowNade(int id, bool thrown = true) {
	int nadeInfo[2];
	nadeInfo = FindNade(id);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int
			client = nadeInfo[0]
			, number = nadeInfo[1];
		if (IsValidEntity(nadeId[client][number])) {
			// get position and angles
			float
				startpt[3]
				, angle[3]
				, speed[3]
				, playerspeed[3];

			GetClientEyePosition(client, startpt);

			for (int i = 0; i <= 2; i++) {
				angle[i] = GetRandomFloat(-180.0, 180.0);
			}
			
			if (thrown) {
				holding[client][number] = false;
				GetClientEyeAngles(client, angle);
				
				float angle2[3];
				angle2 = CopyVector(angle);
				angle[1] += cvNadeAngleCorrection.FloatValue;
				angle2[0] -= cvNadeThrowAngle.FloatValue;
				GetAngleVectors(angle2, speed, NULL_VECTOR, NULL_VECTOR);
				//PrintToChat(client, "angles: [%.2f, %.2f, %.2f]", angle2[0], angle2[1], angle2[2]);
				//tempblock
				//speed[2]+= cvNadeThrowAngle.FloatValue;
				
				
				//speed[0]*= cvConcThrowSpeed.FloatValue; speed[1]*= cvConcThrowSpeed.FloatValue; speed[2]*= cvConcThrowSpeed.FloatValue;
				ScaleVector(speed, cvNadeThrowSpeed.FloatValue);
				if (cvNadePhysics.IntValue > 0) {
					GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerspeed);
					if (cvNadePhysics.IntValue == 1) {
						for (int i = 0; i < 2; i++) {
							if (playerspeed[i] >= 0.0 && speed[i] < 0.0) {
								playerspeed[i] = 0.0;
							}
							else if (playerspeed[i] < 0.0 && speed[i] >= 0.0) {
								playerspeed[i] = 0.0;
							}
						}
						if (playerspeed[2] < 0.0) {
							playerspeed[2] = 0.0;
						}
					}
					AddVectors(speed, playerspeed, speed);
				}
				float sHeight = cvNadeStartHeight.FloatValue;
				if (sHeight!= 0.0) {
					startpt[2] += sHeight;
				}
				TeleportEntity(nadeId[client][number], startpt, angle, speed);
			}
			else {
				float altstartpt[3];
				GetClientAbsOrigin(client, altstartpt);
				GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerspeed);
				ScaleVector(playerspeed, cvNadeHHDisDecrease.FloatValue);
				
				float pSpeedLen = GetVectorLength(playerspeed);
				if (pSpeedLen > 288.0) {
					pSpeedLen = 288.0/pSpeedLen;
					ScaleVector(playerspeed, pSpeedLen);
				}
				
				SubtractVectors(altstartpt, playerspeed, altstartpt);
				altstartpt[2] += cvNadeHHHeight.FloatValue;
				TeleportEntity(nadeId[client][number], altstartpt, angle, NULL_VECTOR);
			}
			if (cvNadeDifGrav.FloatValue!= 1.0) {
				SetEntityGravity(nadeId[client][number], cvNadeDifGrav.FloatValue);
			}
			
			if (cvNadeTrail.IntValue == 1) {
				int color[4];
				//red 
				if (GetClientTeam(client) == 2) { 

					color = { 255, 10, 10, 255 };
				}
				else if (GetClientTeam(client) == 3) {
					color = { 10, 10, 255, 255 };
				}
				else {
					color = { 10, 255, 10, 255 };
				}
				ShowTrail(nadeId[client][number], color);
			}
			EmitSoundToAll(SND_THROWNADE, client);
		}
	}
	else if (cvConcDebug.IntValue == 1) { 
		PrintToServer("info not found for concId %i", id);
	}
}

float CopyVector(float result[3]) {
	return result;
}

public Action beepTimer(Handle timer, any concId) {
	//getting client and nade number info
	int nadeInfo[2];
	nadeInfo = FindNade(concId);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int
			client = nadeInfo[0]
			, number = nadeInfo[1];
		
		//getting max time for this clients nades (default/customized)
		float timerToUse;
		if (personalTimer[client] != -1.0) {
			timerToUse = personalTimer[client];
		}
		else { timerToUse = cvNadeTimer.FloatValue;
		}
		timerToUse -= 1.0;
		
		float diffr = timerToUse-nadeTime[client][number];
		//PrintToChat(client, "diffr = %.2f", diffr);
		if (diffr > 0.01) {
			//if holding make sound come from client pos, else from conc itself, unless sounds are off, then always only for client
			
			if (cvNadeSoundMode.IntValue == 0) {
				if (diffr > 0.41) {
					sEmitSound(client, client, false);
					//EmitSoundToClient(client, SND_NADE_CONC_TIMER);
				}
				else {
					sEmitSound(client, client, true);
					//EmitSoundToClient(client, SND_NADE_CONC_TIMER, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL|SND_CHANGEPITCH, 0.75, 120);
				}
			}
			else {
				if (holding[client][number]) {
					if (diffr > 0.41) {
						//EmitSoundToAll(SND_NADE_CONC_TIMER, client);
						sEmitSound(-1, client, false);
					}
					else {
						sEmitSound(-1, client, true);
						//EmitSoundToAll(SND_NADE_CONC_TIMER, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL|SND_CHANGEPITCH, 0.75, 120);
					}
				}
				else {
					if (diffr > 0.41) {
						sEmitSound(-1, concId, false);
						//EmitSoundToAll(SND_NADE_CONC_TIMER, concId);
					}
					else {
						sEmitSound(-1, concId, true);
						//EmitSoundToAll(SND_NADE_CONC_TIMER, concId, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_CHANGEVOL|SND_CHANGEPITCH, 0.75, 120);
					}
				}
			}
			
			//make sure timer knows for when to set next beep
			//float tempish = (timerToUse-1.0)-nadeTime[client][number];
			//PrintToChat(client, "%.2f", tempish);
			//timer has to leave 0.3, 0.2 and 0.1 for final beeps
			
			if (diffr > 1.41) {
				CreateTimer(1.0, beepTimer, concId);
				nadeTime[client][number] += 1.0;
				//PrintToChat(client, "1 sec delay");
			}
			else {
				float tempish;
				if (diffr > 0.41) {
					tempish = diffr - 0.4;
				}
				//or 0.1 if other timer
				else {
					tempish = 0.4;
				} 

				
				CreateTimer(tempish, beepTimer, concId);
				nadeTime[client][number] += tempish;
				
				//PrintToChat(client, "%.2f sec delay", tempish);
				/*
				if (tempish > 0.0 && tempish < 1.0) {
					
					CreateTimer(tempish, beepTimer, concId);
					nadeTime[client][number] += tempish;
				}
				else {
					CreateTimer(1.0, beepTimer, concId);
					nadeTime[client][number] += 1.0;
				}
				*/
			}
		}
		else {
			if (holding[client][number]) {
				ThrowNade(concId, false);
				holding[client][number] = false;
				NadeExplode(concId, true);
			}
			else {
				NadeExplode(concId, false);
			}
		}
	}
	return Plugin_Handled;
}

void sEmitSound(int client = -1, int locId, bool highpitch) {
	if (client > 0) {
		if (highpitch) {
			EmitSoundToClient(client, SND_NADE_CONC_HIGHPITCH);
		}
		else {
			EmitSoundToClient(client, SND_NADE_CONC_TIMER);
		}
	}
	else {
		if (highpitch) {
			EmitSoundToAll(SND_NADE_CONC_HIGHPITCH, locId);
		}
		else {
			EmitSoundToAll(SND_NADE_CONC_TIMER, locId);
		}
	}
}

public Action delayTimer(Handle timer, any client) {
	nadeDelay[client] = false;
	return Plugin_Handled;
}

public Action helpTimer(Handle timer, any concId) {
	int nadeInfo[2];
	nadeInfo = FindNade(concId);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int
			client = nadeInfo[0]
			, number = nadeInfo[1];

		helpCounter[client][number]++;
		char sTime[32], ln = 0;
		for (int i = 0; i < helpCounter[client][number]; i++) {
			if (i%10 == 0) {
				ln += Format(sTime[ln], 31-ln, "X");
			}
			else { ln += Format(sTime[ln], 31-ln, "I");
			}
		}
		SetHudTextParams(0.04, 0.47 - (0.05 * number), 1.0, 255, 10, 10, 255);
		if (holding[client][number]) {
			ShowSyncHudText(client, HudMsg[client][number], "H %s", sTime);
		}
		else { ShowSyncHudText(client, HudMsg[client][number], "   %s", sTime);
		}
	}
	else {
		if (cvConcDebug.IntValue == 1) { 
			PrintToServer("couldn't find info for concId %i", concId); 
		}
	}
}

void NadeExplode(int concId, bool handHeld = false) {
	int nadeInfo[2];
	nadeInfo = FindNade(concId);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int
			client = nadeInfo[0]
			, number = nadeInfo[1];
		
		//PrintToChat(client, "Fin");
		
		float center[3];
		nadesUsed[client]--;
	
		GetEntPropVector(concId, Prop_Send, "m_vecOrigin", center);
		if (nadeType[client][number] == 0) {
			float radius = cvConcRadius.FloatValue;
			SetupConcBeams(center, radius);
			EmitSoundToAll(SND_NADE_CONC, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, center, NULL_VECTOR, false, 0.0);
			if (cvConcIgnore.IntValue == 1) {
				FindPlayersInRange(center, radius, 0, client, false, -1);
			}
			else { FindPlayersInRange(center, radius, 0, client, true, nadeId[client][number]);
			}
			int damage = 1;
			for (int j = 1; j <= GetMaxClients(); j++) {
				if (PlayersInRange[j] > 0.0) {
					if (j == client || cvConcNoOtherPush.IntValue == 0) {
						ConcPlayer(j, center, radius, client, handHeld);
						char tempString[32]; cvNadeIcon.GetString(tempString, sizeof(tempString));
						DealDamage(j, damage, center, client, DMG_CRUSH, tempString);
					}
				}
			}
		}
		nadeTime[client][number] = -1.0;
		nadeType[client][number] = -1;
		nadeId[client][number] = -1;
		if (timeTimer[client][number] != null) {
			delete timeTimer[client][number];
			timeTimer[client][number] = null;
		}
		helpCounter[client][number] = -1;
		TeleportEntity(concId, holdingArea, NULL_VECTOR, NULL_VECTOR);
		RemoveEdict(concId);

		for (int i = 0; i <= 2; i++) {
			lastOri[client][number][0][i] = 0.0;
			lastOri[client][number][1][i] = 0.0;
		}
		frameTimer[client][number] = 0;
	}
}

void ConcPlayer(int victim, float center[3], float radius, int attacker, bool hh) {
	float
		pSpd[3]
		, cPush[3]
		, pPos[3]
		, distance
		, pointDist
		, calcSpd
		, baseSpd;

	GetClientAbsOrigin(victim, pPos);
	pPos[2] += cvConcBaseHeight.FloatValue;
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", pSpd);
	distance = GetVectorDistance(pPos, center);
	SubtractVectors(pPos, center, cPush);
	NormalizeVector(cPush, cPush);
	pointDist = distance/radius;
	if (hh) { 
		pointDist = pointDist*cvConcHHBoost.FloatValue + 0.25;
		if (pointDist > 1.0) {
			pointDist = 1.0;
		}
	}
	//if (concHelp[attacker] && attacker == victim) { PrintToChat(attacker, "Distance %f of 1.0", pointDist); }
	baseSpd = cvConcBaseSpeed.FloatValue;
	if (cvBlastDistanceMin.FloatValue > pointDist) {
		pointDist = cvBlastDistanceMin.FloatValue;
	}
	calcSpd = baseSpd*pointDist;
	//PrintToChat(victim, "Dist %f, calcSpd %f, pointDist %f", distance, calcSpd, pointDist);
	if (cvConcTest.IntValue == 1) {
		//pointdist 1 = 1450speed, 1.25 = 1959speed, 0.5 = 712.5, 0 = 475
		calcSpd = ((1.0/(baseSpd))*Pow(calcSpd, 2.0))+(baseSpd*0.5); 

	}
	else {
		calcSpd = -1.0*Cosine((calcSpd / baseSpd) * 3.141592) * (baseSpd - (800.0 / 3.0)) + (baseSpd + (800.0 / 3.0));
	}
	//PrintToChat(victim, "pointDist: %f, calcSpeed %i", pointDist, RoundFloat(calcSpd));
	//PrintToChat(victim, "calcSpd after %f", calcSpd);
	//if (calcSpd < 0.5*baseSpd) { calcSpd = 0.5*baseSpd; } 
	ScaleVector(cPush, calcSpd);
	bool OnGround; if (GetEntityFlags(victim) & FL_ONGROUND){
		OnGround = true; } else { OnGround = false;
	}
	if ((hh && victim != attacker) || !hh) {
		if (pSpd[2] < 0.0 && cPush[2] > 0.0 && cvConcBounce.IntValue == 1) {
			pSpd[2] = 0.0;
		}
	}
	//if (concHelp[attacker] && attacker == victim) { PrintToChat(attacker, "Spd[2] %f, push %f, %f, %f", pSpd[2], cPush[0], cPush[1], cPush[2]); }
	AddVectors(pSpd, cPush, pSpd);
	
	if (OnGround) {
		if (pSpd[2] < 800.0/3.0) { pSpd[2] = 800.0/3.0;
	} }
	//PrintToChat(victim, "Final: x %f, y %f, z %f", pSpd[0], pSpd[1], pSpd[2]);
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, pSpd);
}

bool IsClassAllowed(char playerClass[16]) {
	if (cvConcEnabled.IntValue == 1) {
		char sKeywords[64];
		cvConcClass.GetString(sKeywords, 64);
		// = "jump_, rj_, quad_, conc_, cp_, ctf_";
		char sKeyword[16][32];
		int iKeywords = ExplodeString(sKeywords, ",", sKeyword, 16, 16);
		for (int i = 0; i < iKeywords; i++) {
			if (StrContains(playerClass, sKeyword[i], false) > -1) {
				return true;
			}
		}
	}
	return false;
}

void SetupConcBeams(float center[3], float radius) {
	int
		beamcolor[4] = { 255, ... };
	float
		beamcenter[3]
		, height = (radius/2.0)/cvConcRings.FloatValue;
	beamcenter = center;
	for (int f = 0; f < cvConcRings.IntValue; f++) {
		TE_SetupBeamRingPoint(beamcenter, 2.0, radius, gRingModel, gRingModel, 0, 1, 0.35, 6.0, 0.0, beamcolor, 0, FBEAM_FADEOUT);
		TE_SendToAll(0.0);
		beamcenter[2] += height;
	}
}

void ShowTrail(int nade, int color[4]) {
	TE_SetupBeamFollow(nade, gRingModel, 0, 1.0, 10.0, 10.0, 5, color);
	TE_SendToAll();
}

void DealDamage(int victim, int damage, float loc[3], int attacker = 0, int dmg_type = DMG_GENERIC, char[] weapon = "") {
	if (victim > 0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage > 0) {
		char
			dmg_str[16]
			, dmg_type_str[32];
		IntToString(damage, dmg_str, 16); 
		IntToString(dmg_type, dmg_type_str, 32);
		//PrintToChat(victim, "victim %i is valid and hit by attacker %i", victim, attacker);
		int pointHurt = CreateEntityByName("point_hurt");
		if (pointHurt) {
			//float vicOri[3];
			//GetClientAbsOrigin(victim, vicOri);
			TeleportEntity(pointHurt, loc, NULL_VECTOR, NULL_VECTOR);
			//Format(tName, sizeof(tName), "hurtme%d", victim);
			DispatchKeyValue(victim,"targetname","hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","hurtme");
			DispatchKeyValue(pointHurt,"Damage", dmg_str);
			DispatchKeyValue(pointHurt,"DamageType", dmg_type_str);
			if (!StrEqual(weapon,"")) {
				//PrintToChat(victim, "weaponname = %s", weapon);
				DispatchKeyValue(pointHurt,"classname", weapon);
			}
			DispatchSpawn(pointHurt);
			
			AcceptEntityInput(pointHurt,"Hurt",(attacker > 0)?attacker:-1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			//Format(tName, sizeof(tName), "donthurtme%d", victim);
			DispatchKeyValue(victim,"targetname","donthurtme");
			//TeleportEntity(pointHurt[victim], gHoldingArea, NULL_VECTOR, NULL_VECTOR);
			//CreateTimer(0.01, TPHurt, victim);
			RemoveEdict(pointHurt);
		}
	}
}

void AddFolderToDownloadTable(const char[] Directory, bool recursive = false) {
	char
		FileName[64],
		Path[512];
	DirectoryListing
		Dir = OpenDirectory(Directory);
	FileType
		Type;

	while (Dir.GetNext(FileName, sizeof(FileName), Type)) {
		if (Type == FileType_Directory && recursive) {           
			FormatEx(Path, sizeof(Path), "%s/%s", Directory, FileName);
			AddFolderToDownloadTable(Path);
			continue;
			
		}                 
		if (Type != FileType_File) {
			continue;
		}
		FormatEx(Path, sizeof(Path), "%s/%s", Directory, FileName);
		AddFileToDownloadsTable(Path);
	}
}

void FindPlayersInRange(float location[3], float radius, int team, int self, bool trace, int donthit) {
	Handle
		tr;
	float
		rsquare = radius*radius
		, orig[3]
		, distance;

	//if (ff.IntValue == 1){ team = 0; }
	for (int i = 1; i <= MaxClients; i++) {
		PlayersInRange[i] = 0.0;
		if (IsClientInGame(i)) {
			if (IsPlayerAlive(i)) {
				if ((team > 1 && GetClientTeam(i) == team) || team == 0 || i == self) {
					GetClientAbsOrigin(i, orig);
					for (int j = 0; j <= 2; j++) {
						orig[j] -= location[j];
						orig[j] *= orig[j];
					}
					distance = orig[0]+orig[1]+orig[2];
					if (distance < rsquare) {
						if (trace) {
							GetClientEyePosition(i, orig);
							tr = TR_TraceRayFilterEx(location, orig, MASK_SOLID, RayType_EndPoint, TraceRayHitPlayers, donthit);
							if (tr != null) {
								if (TR_GetFraction(tr) > 0.98) {
									PlayersInRange[i] = SquareRoot(distance)/radius;
								}
								delete tr;
							}
							
						}
						else {
							PlayersInRange[i] = SquareRoot(distance)/radius;
						}
					}
				}
			}
		}
	}
}

public bool TraceRayHitPlayers(int entity, int mask, any startent) {
	return (entity != startent && entity <= GetMaxClients() && entity > 0); 
}

public Action DeleteParticles(Handle timer, any particle) {
	if (IsValidEntity(particle)) {
		char classname[128];
		GetEdictClassname(particle, classname, sizeof(classname));
		if (StrEqual(classname, "info_particle_system", false)) {
			RemoveEdict(particle);
		}
		else {
			LogError("DeleteParticles: not removing entity - not a particle '%s'", classname);
		}
	}
}

public void ShowParticle(float pos[3], char[] particlename, float time) {
	int particle = CreateEntityByName("info_particle_system");
	if (IsValidEdict(particle)) {
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", particlename);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(time, DeleteParticles, particle);
	}
	else {
		LogError("ShowParticle: could not create info_particle_system");
	}	
}

void Entity_GetAbsOrigin(int entity, float vec[3])
{
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
}