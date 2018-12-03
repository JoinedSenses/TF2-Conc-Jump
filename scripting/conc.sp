#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <tf2_stocks>
#include <sdkhooks>

#define PLUGIN_VERSION "1.3.2"
#define DMG_TIMEBASED (DMG_PARALYZE | DMG_NERVEGAS | DMG_POISON | DMG_RADIATION | DMG_DROWNRECOVER | DMG_ACID | DMG_SLOWBURN)
#define SND_NADE_CONC "weapons/explode5.wav"
#define SND_THROWNADE "weapons/grenade_throw.wav"
#define SND_NADE_CONC_TIMER "weapons/det_pack_timer.wav"
#define MDL_CONC "models/conc/w_grenade_conc.mdl"
#define SND_NADE_CONC_HIGHPITCH "weapons/det_pack_timer62.wav"

// 950.0, 0.4, 2.25

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
	  g_iRingMOdel
	, g_iNadesUsed[MAXPLAYERS+1]
	, g_iConcToUse[MAXPLAYERS+1]
	, g_iNadeID[MAXPLAYERS+1][10]
	, g_iRealStart
	, g_iNadeType[MAXPLAYERS+1][10]
	, g_iFrameTimer[MAXPLAYERS+1][10];
bool
	  g_bHolding[MAXPLAYERS+1][10]
	, g_bNadeDelay[MAXPLAYERS+1]
	, g_bButtonDown[MAXPLAYERS+1]
	, g_bCanThrow
	, g_bWaitOver
	, g_bLateLoad;
float
	  g_fNadeTime[MAXPLAYERS+1][10]
	, g_fPlayersInRange[MAXPLAYERS+1]
	, g_fHoldingArea[3] = { -10000.0, ... }
	, g_fPersonalTimer[MAXPLAYERS+1]
	, g_fLastTime[MAXPLAYERS+1][10]
	, g_fLastTime2[MAXPLAYERS+1][10]
	, g_fLastOri[MAXPLAYERS+1][10][2][3];
char
	  g_classString[16];
Handle
	  g_hTimer[MAXPLAYERS+1][10];

public Plugin myinfo = {
	name = "Concussion Grenade",
	author = "CrancK",
	description = "gives specified classes the concussion grenade from other tf's",
	version = PLUGIN_VERSION,
	url = "http://github.com/JoinedSenses"
}

public void OnPluginStart() {
	CreateConVar("sm_conc_version", PLUGIN_VERSION, "Conc Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	cvConcEnabled =			CreateConVar("sm_nade_enabled", "1", "Enables the plugin", 0);
	cvNadeWaitPeriod =		CreateConVar("sm_nade_waitperiod", "0", "Recommended if you have setuptime");
	cvConcClass =			CreateConVar("sm_conc_class", "scout,medic", "Which classes are able to use the conc command", 0);
	cvConcRadius =			CreateConVar("sm_conc_radius", "288.0", "Radius of conc blast", 0);
	cvConcMax =				CreateConVar("sm_conc_max", "4", "How many concs a player can have spawned at the same time", 0);
	cvNadeDelay =			CreateConVar("sm_nade_delay", "0.55", "How long a player has to wait before throwing another conc", 0);
	cvNadeTimer =			CreateConVar("sm_nade_timer", "3.0", "How many second to wait until conc explodes", 0);
	cvNadePhysics =			CreateConVar("sm_nade_physics", "0", "Throwing physics, 0 = sm_conc_throwspeed, 1 = sm_conc_throwspeed+ownspeed, 2 = mix", 0);
	cvNadeDifGrav =			CreateConVar("sm_nade_difgrav", "1.75", "Since prop_physics don't use the same physics as a player, this is needed to give it the same terminal velocity", 0);
	cvNadeTrail =			CreateConVar("sm_nade_trail", "1", "Enables a trail following the conc", 0);
	cvNadeSoundMode =		CreateConVar("sm_nade_sounds", "1", "0 = sounds only for client throwing them, 1 = sounds audible for everyone", 0);
	cvNadeThrowSpeed =		CreateConVar("sm_nade_throwspeed", "625.0", "Speed at which concs are thrown", 0);
	cvNadeThrowAngle =		CreateConVar("sm_nade_throwangle", "20.0", "Positive aims higher then crosshair, negative lower", 0);
	cvConcIgnore =			CreateConVar("sm_conc_ignorewalls", "1", "Enables the conc's explosion to push people through walls", 0);
	cvConcNoOtherPush =		CreateConVar("sm_conc_ignoreothers", "1", "Enables the conc's to only push the person that threw it", 0);
	cvConcRings =			CreateConVar("sm_conc_rings", "10.0", "Sets how many rings the conc explosion has", 0);
	cvConcBaseHeight =		CreateConVar("sm_nade_baseheight", "48.0", "Correction for how high the player is when exploding, for making sure it pushes ppl off ground", 0);
	cvConcBaseSpeed =		CreateConVar("sm_conc_basespeed", "950.0", "Base value for conc speed calculations", 0);
	cvNadeIcon =			CreateConVar("sm_nade_killicon", "tf_projectile_rocket", "kill icon for concs", 0);
	cvNadeHHHeight =		CreateConVar("sm_nade_hhheight", "24.0", "How high a nade should be spawned relative to feet on a handheld(feet = 0.0)", 0);
	cvNadeHHDisDecrease =	CreateConVar("sm_nade_hhdisdec", "0.175", "This value*playerspeed = distance from you and nade on a handheld", 0);
	cvConcBounce =			CreateConVar("sm_conc_bounce", "1", "Insures a conc has the power to push someone back up, no matter how fast he's falling", 0);
	cvConcHHBoost =			CreateConVar("sm_conc_hhboost", "3.0", "Correction for hh speed");
	cvNadeAngleCorrection =	CreateConVar("sm_conc_anglecorr", "90.0", "Correction for angle which conc rolls to");
	cvBlastDistanceMin =	CreateConVar("sm_conc_blastdistmin", "0.25", "...");
	cvConcBounceDelay =		CreateConVar("sm_conc_bounce_delay", "0.0608", "...");
	cvFrameTimer =			CreateConVar("sm_frametimer", "1", "...");
	cvConcTest =			CreateConVar("sm_conc_testblast", "1", "...");
	cvNadeGroundRes =		CreateConVar("sm_nade_groundres", "0.6", "...");
	cvNadeStartHeight =		CreateConVar("sm_nade_startheight", "-24.0", "...");
	cvConcDebug =			CreateConVar("sm_conc_debug", "0", "...");

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
	if (g_bLateLoad) {
		g_bCanThrow = g_bWaitOver = true;
	}
	for (int i = 1; i <= MaxClients; i++) {
		g_fPersonalTimer[i] = -1.0;
		for (int j = 0; j < 10; j++) {
			g_fLastTime[i][j] = 0.0;
			g_fLastTime2[i][j] = -1.0;
		}
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
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

	g_iRingMOdel = PrecacheModel("sprites/laser.vmt", true);

	PrecacheSound(SND_THROWNADE, true);
	PrecacheSound(SND_NADE_CONC, true);
	PrecacheSound(SND_NADE_CONC_TIMER, true);
	PrecacheSound(SND_NADE_CONC_HIGHPITCH, true);
	PrecacheModel(MDL_CONC, true);
	
	if (!g_bLateLoad) {
		g_bCanThrow = g_bWaitOver = false;
	}
	for (int i = 1; i <= MaxClients; i++) {
		g_iNadesUsed[i] = 0;
		g_iConcToUse[i] = -1;
		g_bNadeDelay[i] = g_bButtonDown[i] = false;
		
		for (int j = 0; j < 10; j++) {
			g_iNadeID[i][j] = g_iNadeType[i][j] = -1;
			g_fNadeTime[i][j] = g_fLastTime2[i][j] = -1.0;
			g_bHolding[i][j] = false;
			g_hTimer[i][j] = null;
			g_fLastTime[i][j] = 0.0;
			
			g_fLastOri[i][j][0] = NULL_VECTOR;
			g_fLastOri[i][j][1] = NULL_VECTOR;
			g_iFrameTimer[i][j] = 0;
		}
	}
}

public void OnMapEnd() {
	g_bCanThrow = g_bWaitOver = false;
	for (int i = 1; i <= MaxClients; i++) {
		resetClient(i);
	}
}

public void OnClientPostAdminCheck(int client) {
	resetClient(client);
}

public void OnClientDisconnect(int client) {
	resetClient(client);
}

public Action EventRestartRound(Event event, const char[] name, bool dontBroadcast) {
	g_bWaitOver = (cvConcEnabled.BoolValue && cvNadeWaitPeriod.BoolValue);
}

public Action EventPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	classFormat(TF2_GetPlayerClass(client));
	if (IsClassAllowed(g_classString)) {
		for (int i = 0; i < 10; i++) {
			if (g_bHolding[client][i]) {
				ThrowNade(g_iNadeID[client][i], false);
			}
		}
	}
}

// fix for changing class -> removing concs so people cant cheat 
public Action EventPlayerChangeClass(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));

	classFormat(TF2_GetPlayerClass(client));
	if (!IsClassAllowed(g_classString)) {
		resetClient(client);
	}
}

public Action MainEvents(Event event, const char[] name, bool dontBroadcast) {
	if (g_bWaitOver && g_iRealStart%2 == 1 && cvNadeWaitPeriod.BoolValue) {
		if (StrEqual(name, "teamplay_round_start")) {
			g_bCanThrow = false;
		}
		else if (StrEqual(name, "teamplay_round_active")) {
			g_iRealStart++;
			g_bCanThrow = true;
		}
	}
	else if (cvNadeWaitPeriod.BoolValue) {
		if (StrEqual(name, "teamplay_round_start")) {
			g_bCanThrow = false;
		}
		else if (StrEqual(name, "teamplay_round_active")) {
			g_bCanThrow = false;
			g_iRealStart++;
		}
	}
	else {
		g_bCanThrow = g_bWaitOver = true;
	}
}

public Action RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	if (StrEqual(name, "teamplay_game_over")) {
		g_bWaitOver = false;
		g_iRealStart = 0;
	}
	g_bCanThrow = false;
	g_iRealStart = 1;
	// g_bWaitOver = false;
}

public void OnEntityDestroyed(int ent) {
	if (!cvConcEnabled.BoolValue || !IsValidEntity(ent)) {
		return;
	}

	int nadeInfo[2];
	nadeInfo = FindNade(ent);
	if (nadeInfo[0] <= -1 || nadeInfo[1] <= -1) {
		return;
	}

	int client = nadeInfo[0];
	int number = nadeInfo[1];

	g_fNadeTime[client][number] = -2.0;
	g_iNadeType[client][number] = -1;
	g_iNadeID[client][number] = -1;

	delete g_hTimer[client][number];

	g_iNadesUsed[client]--;
}

public Action Command_Conc(int client, int args) {
	if (!cvConcEnabled.BoolValue || !g_bCanThrow) {
		return Plugin_Handled;
	}

	classFormat(TF2_GetPlayerClass(client));

	if (!IsPlayerAlive(client) || IsFakeClient(client) || IsClientObserver(client) || g_bNadeDelay[client] || !IsClassAllowed(g_classString) || g_bButtonDown[client]) {
		return Plugin_Handled;
	}

	for (int i = 0; i < 10; i++) {
		if (g_bHolding[client][i]) {
			return Plugin_Handled;
		}
	}

	int tNade;
	if (g_iNadesUsed[client] >= cvConcMax.IntValue || ((tNade = MakeNade2(client)) <= -1)) {
		return Plugin_Handled;
	}

	g_bHolding[client][tNade] = g_bNadeDelay[client] = g_bButtonDown[client] = true;
	g_iNadesUsed[client]++;
	g_fNadeTime[client][tNade] = 0.0;

	CreateTimer(1.0, beepTimer, g_iNadeID[client][tNade]);
	// g_fLastTime2[client][number] = GetGameTime();
	CreateTimer(cvNadeDelay.FloatValue, delayTimer, client);
	if (cvNadeSoundMode.BoolValue) {
		EmitSoundToAll(SND_NADE_CONC_TIMER, client);
	}
	else {
		EmitSoundToClient(client, SND_NADE_CONC_TIMER);
	}
		
	
	return Plugin_Handled;
}

public Action Command_UnConc(int client, int args) {
	if (!cvConcEnabled.BoolValue) {
		return Plugin_Handled;
	}
	g_bButtonDown[client] = false;
	int tHold[2] = { 0, -1 };
	for (int i = 0; i < 10; i++) {
		if (g_bHolding[client][i]) {
			tHold[0]++;
			tHold[1] = i;
		}
	}
	if (cvConcDebug.BoolValue) { 
		PrintToServer("client %i, g_bHolding %i nades", client, tHold); 
	}
	if (tHold[0] == 1) {
		ThrowNade(g_iNadeID[client][tHold[1]]);
	}
	return Plugin_Handled;
}

public Action Command_ConcHelp(int client, int args) {
	ReplyToCommand(client, "Feature disabled because it's inefficient coding-wise and not even very helpful.");
	return Plugin_Handled;
}

public Action Command_ConcTimer(int client, int args) {
	if (!cvConcEnabled.BoolValue) {
		return Plugin_Handled;
	}
	if (args > 0) {
		char arg[32];
		GetCmdArg(1, arg, sizeof(arg));
		float fArg = StringToFloat(arg);
		if (fArg < 3.0) { 
			ReplyToCommand(client, "Value must be 3.0 or higher"); 
			return Plugin_Handled;
		}
		g_fPersonalTimer[client] = fArg;
	}
	else {
		g_fPersonalTimer[client] = -1.0;
	}
	return Plugin_Handled;
}

int GetFreeNadeSlot(int client) {
	for (int i = 0; i < 10; i++) {
		if (g_iNadeID[client][i] == -1) {
			return i;
		}
	}
	return -1;
}

int FindNade(int id) {
	int value[2] = { -1, -1 };
	if (id <= 0) {
		return value;
	}
	for (int i = 1; i <= MaxClients; i++) {
		for (int j = 0; j < 10; j++) {
			if (g_iNadeID[i][j] == id) {
				value[0] = i;
				value[1] = j;
				return value;
			}
		}
	}
	return value;
}

int MakeNade2(int client, int type = 0) {
	int number = GetFreeNadeSlot(client);
	if (number > -1) {
		char model[255];
		char skin[8];

		if (type == 0) {
			strcopy(model, sizeof(model), MDL_CONC);
		}
		
		
		g_iNadeID[client][number] = CreateEntityByName("prop_physics");
		if (cvConcDebug.BoolValue) { 
			PrintToServer("Making Nade %i (%i) of type %i, for client %i", g_iNadeID[client][number], number, type, client); 
		}
		g_iNadeType[client][number] = type;
		
		if (IsValidEntity(g_iNadeID[client][number])) {
			SetEntPropEnt(g_iNadeID[client][number], Prop_Data, "m_hOwnerEntity", client);
			SetEntityModel(g_iNadeID[client][number], model);
			Format(skin, sizeof(skin), "%d", GetClientTeam(client)-2);
			DispatchKeyValue(g_iNadeID[client][number], "skin", skin);
			
			// DispatchKeyValue(iEnt,"model", szModel);
			DispatchKeyValue(g_iNadeID[client][number],"Solid","6");
			DispatchKeyValue(g_iNadeID[client][number],"physdamagescale","10000.0");
			DispatchKeyValue(g_iNadeID[client][number],"minhealthdmg","0");
			// DispatchKeyValue(g_iNadeID[client][number],"sethealth","500000");
			
			// FSOLID_NOT_SOLID|FSOLID_TRIGGER
			SetEntProp(g_iNadeID[client][number], Prop_Send, "m_usSolidFlags", 12);
			// SOLID_VPHYSICS
			// SetEntProp(g_iNadeID[client][number], Prop_Data, "m_nSolidType", 6);

			// COLLISION_GROUP_DEBRIS 
			SetEntProp(g_iNadeID[client][number], Prop_Send, "m_CollisionGroup", 1); 
			
			SetEntityMoveType(g_iNadeID[client][number], MOVETYPE_NOCLIP);
			
			// test to fix bug where entity nr = -1
			char tName[32];
			Format(tName, sizeof(tName), "tf2nade%d", client);
			DispatchKeyValue(g_iNadeID[client][number], "targetname", tName);
			AcceptEntityInput(g_iNadeID[client][number], "DisableDamageForces");
			
			SDKHook(g_iNadeID[client][number], SDKHook_OnTakeDamage, fOnTakeDamage);
			// SDKHook(g_iNadeID[client][number], SDKHook_Think, OnThink);
			SDKHook(g_iNadeID[client][number], SDKHook_VPhysicsUpdate, PhysUp);
			// Entity_SetMaxSpeed(g_iNadeID[client][number], 3500.0);
			
			DispatchSpawn(g_iNadeID[client][number]);
			
			// SetEntProp(iEnt, Prop_Data,"m_CollisionGroup", 5); 
			// SetEntProp(iEnt, Prop_Data,"m_usSolidFlags", 28);
			
			if (cvConcDebug.BoolValue) { 
				PrintToServer("Nade %i (%i) made of type %i, for client %i", g_iNadeID[client][number], number, type, client); 
			}
			return number;
		}
	}
	return -1;
}

// public Action fOnTakeDamage(iEnt,&iAttacker,&iInflictor,&float:flDamage,&iDamageType) {
public Action fOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
	if (damagetype != DMG_CRUSH) {
		return Plugin_Handled;
	}
    
	static char szAttacker[3];
	IntToString(attacker, szAttacker, sizeof(szAttacker));
	
	// PrintToChatAll("Prop touched %s",!attacker ? "world" : szAttacker);
	int nadeInfo[2];
	nadeInfo = FindNade(victim);

	if (nadeInfo[0] <= -1 || nadeInfo[1] <= -1) {
		return Plugin_Handled;
	}

	int client = nadeInfo[0];
	int number = nadeInfo[1];

	if (!IsValidEntity(g_iNadeID[client][number])) {
		return Plugin_Handled;
	}

	float now = GetGameTime();
	float delay = cvConcBounceDelay.FloatValue;

	if (now - g_fLastTime[client][number] > delay) {
		BounceConc2(victim, damagePosition);
	}
	g_fLastTime[client][number] = now;
	
	
	return Plugin_Handled;
}

void PhysUp(int ent) {
	// PrintToChatAll("something");
	int nadeInfo[2];
	nadeInfo = FindNade(ent);
	if (nadeInfo[0] <= -1 || nadeInfo[1] <= -1) {
		PrintToChatAll("INVALID SHIZZLE");
		return;
	}
	int i = nadeInfo[0];
	int j = nadeInfo[1];
	
	// Saving last 2 origins to calculate speed (cos tf2 is fucked when it comes to finding speed from prop_physics)
	if (g_iFrameTimer[i][j] == cvFrameTimer.IntValue) {
		float absOri[3];
		Entity_GetAbsOrigin(ent, absOri);
	
		for (int k = 0; k <= 2; k++) {
			g_fLastOri[i][j][1][k] = g_fLastOri[i][j][0][k];
			g_fLastOri[i][j][0][k] = absOri[k];
		}
		
		g_iFrameTimer[i][j] = 0;
	}
	g_iFrameTimer[i][j]++;
}


int BounceConc2(int entity, float damagePos[3]) {
	float vOrigin[3];
	float vHeading[3];
	float vAngles[3];
	float vNormal[3];
	float dotProduct;

	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", vOrigin);
	SubtractVectors(damagePos, vOrigin, vHeading);
	GetVectorAngles(vHeading, vAngles);
	
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TEF_ExcludeEntity, entity);
		
	if (!TR_DidHit(trace)) {
		delete trace;
		return -1;
	}

	TR_GetPlaneNormal(trace, vNormal);
	// 270 = flat, 90 = flat aswell.. but upside down
	// PrintToChatAll("Surface Normal: [%.2f, %.2f, %.2f]", vNormal[0], vNormal[1], vNormal[2]);
		
	delete trace;
	
	int nadeInfo[2];
	nadeInfo = FindNade(entity);
	if (nadeInfo[0] > -1 && nadeInfo[1] > -1) {
		int client = nadeInfo[0];
		int number = nadeInfo[1];
		float vVec[3];
		
		// PrintToChat(client, "g_fLastOri[0] %.2f, %.2f, %.2f", g_fLastOri[client][number][0], g_fLastOri[client][number][1], g_fLastOri[client][number][2]);
		// PrintToChat(client, "nowOri[3] %.2f, %.2f, %.2f", vOrigin[0], vOrigin[1], vOrigin[2]);
		
		SubtractVectors(g_fLastOri[client][number][0], g_fLastOri[client][number][1], vVec);
		float ratio = 66.0/cvFrameTimer.FloatValue;
		ScaleVector(vVec, ratio);
		float len = GetVectorLength(vVec);
		
		if (len > 20.0) {
			float vBounceVec[3];
			float vNewAngles[3];
			// PrintToChat(client, "Impact: [%.2f, %.2f, %.2f] |%.2f|", vVec[0], vVec[1], vVec[2], len);
			dotProduct = GetVectorDotProduct(vNormal, vVec)*-1.0;
			
			ScaleVector(vNormal, dotProduct);
			ScaleVector(vNormal, 2.0);
			AddVectors(vVec, vNormal, vBounceVec);
			GetVectorAngles(vBounceVec, vNewAngles);
				
			// PrintToChat(client, "Result: [%.2f, %.2f, %.2f] |%.2f|", vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
			// groundresistance global
			float grRes = cvNadeGroundRes.FloatValue;
			for (int i = 0; i <= 2; i++) {
				if (FloatCompare(vVec[i], vBounceVec[i]) != 0.0) {
					vBounceVec[i] *= grRes;
				}
			}
			// PrintToServer("Angles: [%.2f, %.2f, %.2f] -> [%.2f, %.2f, %.2f]", vAngles[0], vAngles[1], vAngles[2], vNewAngles[0], vNewAngles[1], vNewAngles[2]);
			// PrintToServer("Velocity: [%.2f, %.2f, %.2f] |%.2f| -> [%.2f, %.2f, %.2f] |%.2f|", vVelocity[0], vVelocity[1], vVelocity[2], GetVectorLength(vVelocity), vBounceVec[0], vBounceVec[1], vBounceVec[2], GetVectorLength(vBounceVec));
				
			TeleportEntity(entity, NULL_VECTOR, vNewAngles, vBounceVec);
			g_iFrameTimer[client][number] = 0;
		}
	}
	return 1;
}

bool TEF_ExcludeEntity(int entity, int contentsMask, any data) {
	return (entity != data);
}

void ThrowNade(int id, bool thrown = true) {
	int nadeInfo[2];
	nadeInfo = FindNade(id);
	if (nadeInfo[0] <= -1 || nadeInfo[1] <= -1) {
		if (cvConcDebug.BoolValue) { 
			PrintToServer("info not found for concId %i", id);
		}
		return;
	}
	int client = nadeInfo[0];
	int number = nadeInfo[1];
	if (IsValidEntity(g_iNadeID[client][number])) {
		// get position and angles
		float startpt[3];
		float angle[3];
		float speed[3];
		float playerspeed[3];

		GetClientEyePosition(client, startpt);

		for (int i = 0; i <= 2; i++) {
			angle[i] = GetRandomFloat(-180.0, 180.0);
		}
		
		if (thrown) {
			g_bHolding[client][number] = false;
			GetClientEyeAngles(client, angle);
			
			float angle2[3];
			angle2 = angle;
			angle[1] += cvNadeAngleCorrection.FloatValue;
			angle2[0] -= cvNadeThrowAngle.FloatValue;
			GetAngleVectors(angle2, speed, NULL_VECTOR, NULL_VECTOR);
			// PrintToChat(client, "angles: [%.2f, %.2f, %.2f]", angle2[0], angle2[1], angle2[2]);
			// tempblock
			// speed[2]+= cvNadeThrowAngle.FloatValue;
			
			ScaleVector(speed, cvNadeThrowSpeed.FloatValue);
			if (cvNadePhysics.BoolValue) {
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
			TeleportEntity(g_iNadeID[client][number], startpt, angle, speed);
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
			TeleportEntity(g_iNadeID[client][number], altstartpt, angle, NULL_VECTOR);
		}
		if (cvNadeDifGrav.FloatValue!= 1.0) {
			SetEntityGravity(g_iNadeID[client][number], cvNadeDifGrav.FloatValue);
		}
		
		if (cvNadeTrail.BoolValue) {
			int color[4];

			switch (GetClientTeam(client)) {
				case 2: {
					color = { 255, 10, 10, 255 };
				}
				case 3: {
					color = { 10, 10, 255, 255 };
				}
				default: {
					color = { 10, 255, 10, 255 };
				}
			}

			ShowTrail(g_iNadeID[client][number], color);
		}
		EmitSoundToAll(SND_THROWNADE, client);
	}
}

Action beepTimer(Handle timer, any concId) {
	// getting client and nade number info
	int nadeInfo[2];
	nadeInfo = FindNade(concId);
	if (nadeInfo[0] <= -1 || nadeInfo[1] <= -1) {
		return Plugin_Handled;
	}
	int client = nadeInfo[0];
	int number = nadeInfo[1];
	
	// getting max time for this clients nades (default/customized)
	float timerToUse = (g_fPersonalTimer[client] != -1.0) ? g_fPersonalTimer[client] : cvNadeTimer.FloatValue;

	timerToUse -= 1.0;
	
	float diffr = timerToUse-g_fNadeTime[client][number];
	// PrintToChat(client, "diffr = %.2f", diffr);
	if (diffr > 0.01) {
		// if g_bHolding make sound come from client pos, else from conc itself, unless sounds are off, then always only for client
		sEmitSound(-1, !cvNadeSoundMode.BoolValue ? client : g_bHolding[client][number] ? client : concId, (diffr <= 0.41));
		
		// make sure timer knows for when to set next beep
		if (diffr > 1.41) {
			CreateTimer(1.0, beepTimer, concId);
			g_fNadeTime[client][number] += 1.0;
			// PrintToChat(client, "1 sec delay");
		}
		else {
			float tempish = (diffr > 0.41) ? (diffr - 0.4) : 0.4;

			CreateTimer(tempish, beepTimer, concId);
			g_fNadeTime[client][number] += tempish;
		}
	}
	else {
		if (g_bHolding[client][number]) {
			ThrowNade(concId, false);
			g_bHolding[client][number] = false;
			NadeExplode(concId, true);
		}
		else {
			NadeExplode(concId, false);
		}
	}
	return Plugin_Handled;
}

void sEmitSound(int client = -1, int locId, bool highpitch) {
	if (client > 0) {
		EmitSoundToClient(client, (highpitch) ? SND_NADE_CONC_HIGHPITCH : SND_NADE_CONC_TIMER);
	}
	else {
		EmitSoundToAll((highpitch) ? SND_NADE_CONC_HIGHPITCH : SND_NADE_CONC_TIMER, locId);
	}
}

Action delayTimer(Handle timer, any client) {
	g_bNadeDelay[client] = false;
	return Plugin_Handled;
}

void NadeExplode(int concId, bool handHeld = false) {
	int nadeInfo[2];
	nadeInfo = FindNade(concId);

	if (nadeInfo[0] <= -1 || nadeInfo[1] <= -1) {
		return;
	}

	int client = nadeInfo[0];
	int number = nadeInfo[1];
	
	// PrintToChat(client, "Fin");
	
	float center[3];
	g_iNadesUsed[client]--;

	GetEntPropVector(concId, Prop_Send, "m_vecOrigin", center);
	if (g_iNadeType[client][number] == 0) {
		float radius = cvConcRadius.FloatValue;
		SetupConcBeams(center, radius);
		EmitSoundToAll(SND_NADE_CONC, 0, SNDCHAN_WEAPON, SNDLEVEL_TRAFFIC, SND_NOFLAGS, SNDVOL_NORMAL, 100, _, center, NULL_VECTOR, false, 0.0);

		FindPlayersInRange(center, radius, 0, client, !cvConcIgnore.BoolValue, cvConcIgnore.BoolValue ? -1 : g_iNadeID[client][number]);

		int damage = 1;
		for (int j = 1; j <= GetMaxClients(); j++) {
			if (g_fPlayersInRange[j] > 0.0 && (j == client || !cvConcNoOtherPush.BoolValue)) {
				ConcPlayer(j, center, radius, client, handHeld);
				char tempString[32];
				cvNadeIcon.GetString(tempString, sizeof(tempString));
				DealDamage(j, damage, center, client, DMG_CRUSH, tempString);
			}
		}
	}
	g_fNadeTime[client][number] = -1.0;
	g_iNadeType[client][number] = -1;
	g_iNadeID[client][number] = -1;

	delete g_hTimer[client][number];

	TeleportEntity(concId, g_fHoldingArea, NULL_VECTOR, NULL_VECTOR);
	RemoveEdict(concId);

	for (int i = 0; i <= 2; i++) {
		g_fLastOri[client][number][0][i] = 0.0;
		g_fLastOri[client][number][1][i] = 0.0;
	}
	g_iFrameTimer[client][number] = 0;
}

void ConcPlayer(int victim, float center[3], float radius, int attacker, bool hh) {
	float pSpd[3];
	float cPush[3];
	float pPos[3];

	GetClientAbsOrigin(victim, pPos);
	pPos[2] += cvConcBaseHeight.FloatValue;
	GetEntPropVector(victim, Prop_Data, "m_vecVelocity", pSpd);
	float distance = GetVectorDistance(pPos, center);
	SubtractVectors(pPos, center, cPush);
	NormalizeVector(cPush, cPush);
	float pointDist = distance/radius;
	if (hh) { 
		pointDist = pointDist*cvConcHHBoost.FloatValue + 0.25;
		if (pointDist > 1.0) {
			pointDist = 1.0;
		}
	}

	float baseSpd = cvConcBaseSpeed.FloatValue;
	if (cvBlastDistanceMin.FloatValue > pointDist) {
		pointDist = cvBlastDistanceMin.FloatValue;
	}
	float calcSpd = baseSpd*pointDist;
	// PrintToChat(victim, "Dist %f, calcSpd %f, pointDist %f", distance, calcSpd, pointDist);
	if (cvConcTest.BoolValue) {
		// pointdist 1 = 1450speed, 1.25 = 1959speed, 0.5 = 712.5, 0 = 475
		calcSpd = ((1.0/(baseSpd))*Pow(calcSpd, 2.0))+(baseSpd*0.5); 
	}
	else {
		calcSpd = -1.0*Cosine((calcSpd / baseSpd)*3.141592)*(baseSpd - (800.0 / 3.0))+(baseSpd + (800.0 / 3.0));
	}
	// PrintToChat(victim, "pointDist: %f, calcSpeed %i", pointDist, RoundFloat(calcSpd));
	// PrintToChat(victim, "calcSpd after %f", calcSpd);

	ScaleVector(cPush, calcSpd);
	if (((hh && victim != attacker) || !hh) && (pSpd[2] < 0.0 && cPush[2] > 0.0 && cvConcBounce.BoolValue)) {
		pSpd[2] = 0.0;
	}

	AddVectors(pSpd, cPush, pSpd);
	
	if (GetEntityFlags(victim) & FL_ONGROUND) {
		if (pSpd[2] < 800.0/3.0) {
			pSpd[2] = 800.0/3.0;
		}
	}
	// PrintToChat(victim, "Final: x %f, y %f, z %f", pSpd[0], pSpd[1], pSpd[2]);
	TeleportEntity(victim, NULL_VECTOR, NULL_VECTOR, pSpd);
}

bool IsClassAllowed(char playerClass[16]) {
	if (!cvConcEnabled.BoolValue) {
		return false;
	}
	char sKeywords[64];
	char sKeyword[16][32];

	cvConcClass.GetString(sKeywords, 64);
	int iKeywords = ExplodeString(sKeywords, ",", sKeyword, 16, 16);
	for (int i = 0; i < iKeywords; i++) {
		if (StrContains(playerClass, sKeyword[i], false) > -1) {
			return true;
		}
	}
	return false;
}

void SetupConcBeams(float center[3], float radius) {
	int beamcolor[4] = { 255, ... };
	float beamcenter[3];
	float height = (radius/2.0)/cvConcRings.FloatValue;

	beamcenter = center;
	for (int f = 0; f < cvConcRings.IntValue; f++) {
		TE_SetupBeamRingPoint(beamcenter, 2.0, radius, g_iRingMOdel, g_iRingMOdel, 0, 1, 0.35, 6.0, 0.0, beamcolor, 0, FBEAM_FADEOUT);
		TE_SendToAll(0.0);
		beamcenter[2] += height;
	}
}

void ShowTrail(int nade, int color[4]) {
	TE_SetupBeamFollow(nade, g_iRingMOdel, 0, 1.0, 10.0, 10.0, 5, color);
	TE_SendToAll();
}

void DealDamage(int victim, int damage, float loc[3], int attacker = 0, int dmg_type = DMG_GENERIC, char[] weapon = "") {
	if (victim > 0 && IsValidEdict(victim) && IsClientInGame(victim) && IsPlayerAlive(victim) && damage > 0) {
		char dmg_str[16];
		char dmg_type_str[32];

		IntToString(damage, dmg_str, 16); 
		IntToString(dmg_type, dmg_type_str, 32);
		// PrintToChat(victim, "victim %i is valid and hit by attacker %i", victim, attacker);
		int pointHurt = CreateEntityByName("point_hurt");
		if (pointHurt) {
			TeleportEntity(pointHurt, loc, NULL_VECTOR, NULL_VECTOR);

			DispatchKeyValue(victim,"targetname","hurtme");
			DispatchKeyValue(pointHurt,"DamageTarget","hurtme");
			DispatchKeyValue(pointHurt,"Damage", dmg_str);
			DispatchKeyValue(pointHurt,"DamageType", dmg_type_str);
			if (!StrEqual(weapon,"")) {
				// PrintToChat(victim, "weaponname = %s", weapon);
				DispatchKeyValue(pointHurt,"classname", weapon);
			}
			DispatchSpawn(pointHurt);
			
			AcceptEntityInput(pointHurt,"Hurt", (attacker > 0) ? attacker : -1);
			DispatchKeyValue(pointHurt,"classname","point_hurt");
			DispatchKeyValue(victim,"targetname","donthurtme");
			RemoveEdict(pointHurt);
		}
	}
}

void AddFolderToDownloadTable(const char[] Directory, bool recursive = false) {
	char FileName[64];
	char Path[512];
	DirectoryListing Dir = OpenDirectory(Directory);
	FileType Type;

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
	Handle tr;
	float rsquare = radius*radius;
	float orig[3];
	float distance;

	for (int i = 1; i <= MaxClients; i++) {
		g_fPlayersInRange[i] = 0.0;
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || (!((team > 1 && (GetClientTeam(i) == team)) || team == 0 || i == self))) {
			continue;
		}

		GetClientAbsOrigin(i, orig);
		for (int j = 0; j <= 2; j++) {
			orig[j] -= location[j];
			orig[j] *= orig[j];
		}
		distance = orig[0]+orig[1]+orig[2];
		if (distance >= rsquare) {
			continue;
		}
		if (trace) {
			GetClientEyePosition(i, orig);
			tr = TR_TraceRayFilterEx(location, orig, MASK_SOLID, RayType_EndPoint, TraceRayHitPlayers, donthit);
			if (tr != null) {
				if (TR_GetFraction(tr) > 0.98) {
					g_fPlayersInRange[i] = SquareRoot(distance)/radius;
				}
				delete tr;
			}
		}
		else {
			g_fPlayersInRange[i] = SquareRoot(distance)/radius;
		}
	}
}

public bool TraceRayHitPlayers(int entity, int mask, any startent) {
	return (entity != startent && entity <= GetMaxClients() && entity > 0); 
}

void resetClient(int client) {
	for (int i = 0; i < 10; i++) {
		if (g_iNadeID[client][i] != -1) {
			if (IsValidEntity(g_iNadeID[client][i])) {
				RemoveEdict(g_iNadeID[client][i]);
			}
			g_iNadeID[client][i] = -1;
		}
		g_fNadeTime[client][i] = -1.0;
		g_bHolding[client][i] = false;
		g_iNadeType[client][i] = -1;
		delete g_hTimer[client][i];
	}
	g_fPersonalTimer[client] = -1.0;
	g_bNadeDelay[client] = g_bButtonDown[client] = false;
	g_iConcToUse[client] = -1;
	g_iNadesUsed[client] = 0;
}

void Entity_GetAbsOrigin(int entity, float vec[3]) {
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
}

void classFormat(TFClassType class) {
	switch(class) {
		case TFClass_Scout: Format(g_classString, sizeof(g_classString), "scout");
		case TFClass_Sniper: Format(g_classString, sizeof(g_classString), "sniper");
		case TFClass_Soldier: Format(g_classString, sizeof(g_classString), "soldier");
		case TFClass_DemoMan: Format(g_classString, sizeof(g_classString), "demoman");
		case TFClass_Medic: Format(g_classString, sizeof(g_classString), "medic");
		case TFClass_Heavy: Format(g_classString, sizeof(g_classString), "heavy");
		case TFClass_Pyro: Format(g_classString, sizeof(g_classString), "pyro");
		case TFClass_Spy: Format(g_classString, sizeof(g_classString), "spy");
		case TFClass_Engineer: Format(g_classString, sizeof(g_classString), "engineer");
	}
}