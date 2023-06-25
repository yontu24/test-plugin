#include <amxmodx>
#include <amxmisc>
#include <hamsandwich>
#include <fakemeta>
#include <csx>
#include <nvault>


// --------------------------------------------
//   ------------- DE EDITAT ---------------
// --------------------------------------------
// pentru test, sterge '//' din fata la '#define USE_MONEY'
// daca vrei sa testezi pe dusts, adauga '//' in fata
//#define USE_MONEY

// daca adaugi '//' in fata, hudul va fi dezativat
//#define SHOW_HUD

// accesul comenzii /level
#define ADMIN_ACCESS	ADMIN_BAN_TEMP	// "v"

// tag-ul in chat
new const Tag[] = "[LEVEL MOD]";
// --------------------------------------------
//   ------------- DE EDITAT ---------------
// --------------------------------------------


#if defined USE_MONEY
native cs_set_user_money(id, money, flash=1);
native cs_get_user_money(id);
#else
native csgo_get_user_dusts(id);
native csgo_set_user_dusts(id, num);
#endif 

new const PLUGIN_NAME[] 	=	"Level System";
new const PLUGIN_VERSION[] 	=	"4.0";
new const PLUGIN_AUTHOR[] 	= 	"YONTU";
//new const PLUGIN_UPDATE[] =	"28.12.2021";

#define SetPlayerBit(%1,%2)		(%1 |= (1 << (%2 & 31)))
#define ClearPlayerBit(%1,%2)	(%1 &= ~(1 << (%2 & 31)))
#define CheckPlayerBit(%1,%2)	(%1 & (1 << (%2 & 31)))
#define is_user_valid(%1)		(1 <= %1 <= 32)
#define TASK_SHOWHUD			122121

enum _:Stats {
	RANK[32],
	XP,
	COST,
	POWER[64]
};

new g_maxLevel = 1;
new g_myXP[33], g_myLevel[33], g_myPower[33], g_myPowerActive[33], g_playerName[33][32], g_isAlive, g_isConnected;
new g_hostName[64], cvar_hostname, g_Vault;

#if defined SHOW_HUD
new SyncHudMessage;
#endif

enum _data_cvars {
	cvarname[32],
	cvarvalue[5],
	cvardesc[256]
}

enum _:cvars {
	xp_kill = 0,
	xp_hs,
	xp_kill_knife,
	xp_hs_knife,
	xp_he,
	// xp_plant_bmb,
	// xp_defuse_bmb,
	// xp_explode_bmb,
	xp_levelup_protection,
	xp_levelup_effects
};
new cvar[cvars], cvar_cache[cvars];

new Array:levelModArray;
new g_fwdUserNameChanged;
new g_fwdUserLevelUpdated, g_fwdUserUnlockedPower;

public plugin_init() {
	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);
	register_cvar("level_mod_", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_SERVER);
	set_cvar_string("level_mod_", PLUGIN_VERSION);

	cvar[xp_kill] = register_cvar("xp_kill", "1");
	cvar[xp_hs] = register_cvar("xp_hs", "3");
	cvar[xp_kill_knife] = register_cvar("xp_kill_knife", "1");
	cvar[xp_hs_knife] = register_cvar("xp_hs_knife", "3");
	cvar[xp_he] = register_cvar("xp_he", "1");
	cvar[xp_levelup_protection] = register_cvar("xp_levelup_protection", "1");
	cvar[xp_levelup_effects] = register_cvar("xp_levelup_effects", "0");

	register_event("HLTV", "event_NewRound", "a", "1=0", "2=0");
	register_event("SayText", "event_SayText", "a", "2=#Cstrike_Name_Change");
	
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn", 1);

	register_concmd("amx_info", "CmdInfo", ADMIN_ACCESS, "display current levels");

	register_clcmd("say /level", "CmdManagePlayers");
	register_clcmd("say_team /level", "CmdManagePlayers");

	register_clcmd("say /power", "CmdSelectPower");
	register_clcmd("say_team /power", "CmdSelectPower");
	
	register_clcmd("say /xp", "CmdXp");
	register_clcmd("say_team /xp", "CmdXp");

	register_clcmd("nightvision", "cmd_nightvision");

	g_fwdUserLevelUpdated = CreateMultiForward("levelmod_level_updated", ET_IGNORE, FP_CELL, FP_CELL);
	g_fwdUserUnlockedPower = CreateMultiForward("levelmod_user_unlocked_power", ET_IGNORE, FP_CELL, FP_CELL);

	#if defined SHOW_HUD
	SyncHudMessage = CreateHudSyncObj();
	#endif

	cvar_hostname = get_cvar_pointer("hostname");
	
	g_Vault = nvault_open("_level_mod_");
	if (g_Vault == INVALID_HANDLE)
		set_fail_state("Eroare la deschiderea bazei de date din foldeurul data/vault.");
	
	levelModArray = ArrayCreate(Stats);
	new levelModArrayTmp[Stats];
	ArrayClear(levelModArray);
	ArrayPushArray(levelModArray, levelModArrayTmp);
}

public plugin_end() {
	nvault_close(g_Vault);
	ArrayDestroy(levelModArray);
	DestroyForward(g_fwdUserLevelUpdated);
	DestroyForward(g_fwdUserUnlockedPower);
}

public CmdInfo(id, level, cid) {
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED;

	console_print(id, "========= | %s | =========", PLUGIN_NAME);
	new levelmoddata[Stats];
	for (new level = 1; level <= g_maxLevel; level++) {
		ArrayGetArray(levelModArray, level, levelmoddata);
		console_print(id, "Level: %d | XP: %d | Rank: '%s' | Cost: %d | Power: '%s'^n", level, levelmoddata[XP], levelmoddata[RANK], levelmoddata[COST], levelmoddata[POWER]);
	}
	console_print(id, "========= | %s | =========", PLUGIN_NAME);

	return PLUGIN_CONTINUE;
}

public plugin_cfg() {
	for (new i = 0; i <= 7; i++)
		cvar_cache[i] = get_pcvar_num(cvar[i]);

	get_pcvar_string(cvar_hostname, g_hostName, charsmax(g_hostName));
}

public plugin_natives() {
	levelModArray = ArrayCreate(Stats);
	
	// Player specific natives
	register_library("levelmody");
	register_native("set_user_xp", "native_set_user_xp", 1);
	register_native("get_user_xp", "native_get_user_xp", 1);
	register_native("get_user_rankname", "native_get_user_rankname", 1);
	register_native("get_user_level", "native_get_user_level", 1);
	register_native("get_max_level", "native_get_g_maxLevel", 1);
	register_native("get_user_next_level_xp", "native_get_user_next_level_xp", 1);
	register_native("register_level", "native_register_level", 1);

	// power natives
	register_native("is_power_active", "native_is_power_active", 1);
	register_native("has_power", "native_has_power", 1);
	register_native("remove_power", "native_remove_power", 1);
	register_native("set_power", "native_set_power", 1);
}

public native_remove_power(id, level, bool:refund) {
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	if (!(1 <= level <= g_maxLevel))
		log_error(AMX_ERR_NATIVE, "%s: Invalid player level (%d). Maximum level is %d.", PLUGIN_NAME, level, g_maxLevel);

	ClearPlayerBit(g_myPower[id], level);
	SetPlayerBit(g_myPowerActive[id], level);

	if (refund) {
		new db_levelMod[Stats];
		ArrayGetArray(levelModArray, level, db_levelMod);

#if defined USE_MONEY
		cs_set_user_money(id, cs_get_user_money(id) + db_levelMod[COST]);
#else
		csgo_set_user_dusts(id, csgo_get_user_dusts(id) + db_levelMod[COST]);
#endif 
	}
}

public native_set_power(id, level, bool:buy) {
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	if (!(1 <= level <= g_maxLevel))
		log_error(AMX_ERR_NATIVE, "%s: Invalid player level (%d). Maximum level is %d.", PLUGIN_NAME, level, g_maxLevel);

	SetPlayerBit(g_myPower[id], level);
	SetPlayerBit(g_myPowerActive[id], level);

	if (buy) {
		new db_levelMod[Stats];
		ArrayGetArray(levelModArray, level, db_levelMod);
#if defined USE_MONEY
		cs_set_user_money(id, min(cs_get_user_money(id) - db_levelMod[COST], 0));
#else
		csgo_set_user_dusts(id, min(csgo_get_user_dusts(id) - db_levelMod[COST], 0));
#endif
	}
}

public native_is_power_active(id, level) {
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	if (!(1 <= level <= g_maxLevel))
		log_error(AMX_ERR_NATIVE, "%s: Invalid player level (%d). Maximum level is %d.", PLUGIN_NAME, level, g_maxLevel);

	return CheckPlayerBit(g_myPowerActive[id], level) ? true : false;
}

public native_has_power(id, level) {
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	if (!(1 <= level <= g_maxLevel))
		log_error(AMX_ERR_NATIVE, "%s: Invalid player level (%d). Maximum level is %d.", PLUGIN_NAME, level, g_maxLevel);
		
	return CheckPlayerBit(g_myPower[id], level) ? true : false;
}

// level = register_level("My rank", 250, 1000, "My Power");
public native_register_level(const rank[], xp, cost, const power[]) {
	param_convert(1);
	param_convert(4);

	if (!levelModArray)
		log_error(AMX_ERR_NATIVE, "Can't register level yet (%s).", rank);

	if (strlen(rank) < 1)
		log_error(AMX_ERR_NATIVE, "Can't register level an empty rank name.");

	new levelModArrayTmp[Stats];
	levelModArrayTmp[XP] = xp;
	levelModArrayTmp[COST] = cost;
	copy(levelModArrayTmp[RANK], charsmax(levelModArrayTmp[RANK]), rank);
	copy(levelModArrayTmp[POWER], charsmax(levelModArrayTmp[POWER]), power);
		
	ArrayPushArray(levelModArray, levelModArrayTmp);
	g_maxLevel++;

	log_message("Level %d (rank `%s`) has been registered successfully.", g_maxLevel, levelModArrayTmp[RANK]);
	return g_maxLevel;
}

public native_set_user_xp(id, xp) {
	// if (iParams != 4)
	// 	log_error(AMX_ERR_NATIVE, "%s: Invalid params number. Needs 4 params insted of %d.", PLUGIN_NAME, iParams);

	// new id = get_param(1);
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	set_user_xp(id, xp);
}

public native_get_user_xp(id) {
	// if (iParams != 1)
	// 	log_error(AMX_ERR_NATIVE, "%s: Invalid params number. Needs 1 param insted of %d.", PLUGIN_NAME, iParams);
		
	// new id = get_param(1);
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	return g_myXP[id];
}

public native_get_user_level(id) {
	// if (iParams != 1)
	// 	log_error(AMX_ERR_NATIVE, "%s: Invalid params number. Needs 1 param insted of %d.", PLUGIN_NAME, iParams);
	
	// new id = get_param(1);
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	return g_myLevel[id];
}

public native_get_g_maxLevel() {
	// if (iParams != 0)
	// 	log_error(AMX_ERR_NATIVE, "%s: Invalid params number. No param needed, but found %d.", PLUGIN_NAME, iParams);

	return g_maxLevel;
}

public native_get_user_next_level_xp(id) {
	// if (iParams != 1)
	// 	log_error(AMX_ERR_NATIVE, "%s: Invalid params number. Needs 1 param insted of %d.", PLUGIN_NAME, iParams);
	
	// new id = get_param(1);
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	new db_levelMod[Stats];
	ArrayGetArray(levelModArray, g_myLevel[id], db_levelMod);
	return db_levelMod[XP];
}

public native_get_user_rankname(id, model[]) {
	param_convert(2);
	// if (iParams != 1)
	// 	log_error(AMX_ERR_NATIVE, "%s: Invalid params number. Needs 1 param insted of %d.", PLUGIN_NAME, iParams);
	
	// new id = get_param(1);
	if (!is_user_valid(id))
		log_error(AMX_ERR_NATIVE, "%s: Invalid Player (%d).", PLUGIN_NAME, id);

	new db_levelMod[Stats];
	ArrayGetArray(levelModArray, g_myLevel[id], db_levelMod);
	
	copy(model, 31, db_levelMod[RANK])
}

public client_putinserver(id) {
	get_user_name(id, g_playerName[id], 31);
	g_myXP[id] = 0;
	SetPlayerBit(g_myPower[id], 0);
	SetPlayerBit(g_isConnected, id);

	for (new level = 0; level < 32; level++)
		SetPlayerBit(g_myPowerActive[id], level);

	if (is_user_alive(id))
		SetPlayerBit(g_isAlive, id);
	else
		ClearPlayerBit(g_isAlive, id);
	
	fnLoadXP(id);
	g_myLevel[id] = computeUserLevel(id);

	#if defined SHOW_HUD
	set_task(1.0, "task_ShowHUD", id + TASK_SHOWHUD, _, _, "b");
	#endif
}

public cmd_nightvision(id) {
	CmdSelectPower(id);
	return PLUGIN_HANDLED_MAIN;
}

public client_disconnected(id) {
	ClearPlayerBit(g_isAlive, id);
	ClearPlayerBit(g_isConnected, id);

	fnSaveXP(id);
	#if defined SHOW_HUD
	remove_task(id + TASK_SHOWHUD);
	#endif
}

// thx ConnorMcLeod
public fw_ChangeName(id) {
	static const name[] = "name"
	static szOldName[32], szNewName[32];

	pev(id, pev_netname, szOldName, charsmax(szOldName));
	if (szOldName[0]) {
		get_user_info(id, name, szNewName, charsmax(szNewName));
		if (!equal(szOldName, szNewName)) {
			fnSaveXP(id);
			if (task_exists(id + TASK_SHOWHUD))
				remove_task(id + TASK_SHOWHUD);
			
			client_putinserver(id);
		}
	}

	unregister_forward(FM_ClientUserInfoChanged, g_fwdUserNameChanged, 1);
}

public fw_PlayerSpawn(id) {
	if (!is_user_alive(id))
		return HAM_IGNORED;
	
	SetPlayerBit(g_isAlive, id);
	return HAM_IGNORED;
}

public event_NewRound() {
	for (new cvarId = 0; cvarId <= 7; cvarId++)
		cvar_cache[cvarId] = get_pcvar_num(cvar[cvarId]);
}

public event_SayText(iMsg, iDestination, iEntity) {
	static const functionName[] = "fw_ChangeName";
	g_fwdUserNameChanged = register_forward(FM_ClientUserInfoChanged, functionName, 1);
}

public client_death(killer, victim, wpnindex, hitplace, TK) {
	if (killer == victim || !CheckPlayerBit(g_isAlive, killer))
		return;

	ClearPlayerBit(g_isAlive, victim);

	// optional
	//if (g_myLevel[killer] == g_maxLevel)
	//	return;
	
	new xp;
	switch(wpnindex) {
		case CSW_KNIFE: {
			if (hitplace == HIT_HEAD) xp = (cvar_cache[xp_hs_knife] == 0) ? 0 : cvar_cache[xp_hs_knife];
			else xp = (cvar_cache[xp_kill_knife] == 0) ? 0 : cvar_cache[xp_kill_knife];
		}
		case CSW_HEGRENADE: xp = (cvar_cache[xp_he] == 0) ? 0 : cvar_cache[xp_he];
		default: {
			if (hitplace == HIT_HEAD) xp = (cvar_cache[xp_hs] == 0) ? 0 : cvar_cache[xp_hs];
			else xp = (cvar_cache[xp_kill] == 0) ? 0 : cvar_cache[xp_kill];
		}
	}

	if (xp != 0)
		set_user_xp(killer, xp);
}

public CmdXp(id) {
	if (!is_user_connected(id))
		return PLUGIN_HANDLED_MAIN;

	static db_levelMod[Stats];
	ArrayGetArray(levelModArray, g_myLevel[id], db_levelMod);
	client_print_color(id, print_team_default, "^4%s^1 Your level is [^3%d^1/^3%d^1]. Current XP: [^3%d^1/^3%d^1]", Tag, g_myLevel[id], g_maxLevel, g_myXP[id], db_levelMod[XP]);

	return PLUGIN_HANDLED_MAIN;
}

public CmdSelectPower(id) {
	if (!CheckPlayerBit(g_isConnected, id))
		return;
	
	static text[256], key[2];
#if defined USE_MONEY
	new money = cs_get_user_money(id);
	formatex(text, charsmax(text), "Power Menu^nMy level: %d | My money: %d$", g_myLevel[id], money);
#else
	new money = csgo_get_user_dusts(id);
	formatex(text, charsmax(text), "Power Menu^nMy level: %d | My dusts: %d", g_myLevel[id], money);
#endif

	new menu = menu_create(text, "PowerMenuHandler");
	new callback = menu_makecallback("PowerMenuCallBack");

	new db_levelMod[Stats];
	for (new level = 1; level <= g_maxLevel; level++) {
		ArrayGetArray(levelModArray, level, db_levelMod);

		if (equal(db_levelMod[POWER], "NONE"))
			continue;

		if (g_myLevel[id] < level)
			formatex(text, charsmax(text), "\d%s [Level:\r %i\d] [LOCKED]", db_levelMod[POWER], level);
		else {
#if defined USE_MONEY
			if (!CheckPlayerBit(g_myPower[id], level)) {
				if (money < db_levelMod[COST])
					formatex(text, charsmax(text), "\d%s [Level:\r %i\d] [\yNEED %d$ MORE\d]", db_levelMod[POWER], level, db_levelMod[COST] - money);
				else
					formatex(text, charsmax(text), "\y%s \w[Level:\r %i\w] [\yUNLOCK %d$\w]", db_levelMod[POWER], level, db_levelMod[COST]);
			} else
				formatex(text, charsmax(text), "\w%s \w[Level:\r %i\w] [%s\w]", db_levelMod[POWER], level, CheckPlayerBit(g_myPowerActive[id], level) ? "\yACTIVE" : "\dINACTIVE");
#else
			if (!CheckPlayerBit(g_myPower[id], level)) {
				if (money < db_levelMod[COST])
					formatex(text, charsmax(text), "\d%s [Level:\r %i\d] [\yNEED %d DUSTS MORE\d]", db_levelMod[POWER], level, db_levelMod[COST] - money);
				else
					formatex(text, charsmax(text), "\y%s \w[Level:\r %i\w] [\yUNLOCK %d DUSTS\w]", db_levelMod[POWER], level, db_levelMod[COST]);
			} else
				formatex(text, charsmax(text), "\w%s \w[Level:\r %i\w] [%s\w]", db_levelMod[POWER], level, CheckPlayerBit(g_myPowerActive[id], level) ? "\yACTIVE" : "\dINACTIVE");
#endif
		}

		key[0] = level;
		key[1] = 0;
		menu_additem(menu, text, key, _, callback);
	}
	menu_setprop(menu, MPROP_EXIT, MEXIT_ALL);
	menu_setprop(menu, MPROP_PERPAGE, 6);
	menu_setprop(menu, MPROP_SHOWPAGE, false)
	menu_display(id, menu);
}

public PowerMenuHandler(id, menu, item) {
	if (item == MENU_EXIT || !CheckPlayerBit(g_isConnected, id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}

	new item_access, callback, info[2], name[32];
	menu_item_getinfo(menu, item, item_access, info, charsmax(info), name, charsmax(name), callback);

	new level = info[0];

	if (CheckPlayerBit(g_myPowerActive[id], level)) {
		ClearPlayerBit(g_myPowerActive[id], level);
	} else {
		SetPlayerBit(g_myPowerActive[id], level);
	}
	
	set_task(0.1, "CmdSelectPower", id);

	if (CheckPlayerBit(g_myPower[id], level)) {
		menu_destroy(menu);
		return PLUGIN_CONTINUE;
	}

	SetPlayerBit(g_myPower[id], level);

	new db_levelMod[Stats];
	ArrayGetArray(levelModArray, level, db_levelMod);
#if defined USE_MONEY
	cs_set_user_money(id, cs_get_user_money(id) - db_levelMod[COST]);
#else
	csgo_set_user_dusts(id, csgo_get_user_dusts(id) - db_levelMod[COST]);
#endif

	client_print_color(id, print_team_default, "^4%s^1 You have unlocked a new power:^3 %s^1. (%d)", Tag, db_levelMod[POWER], level);

	new returnVal;
	ExecuteForward(g_fwdUserUnlockedPower, returnVal, id, level);

	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public PowerMenuCallBack(id, menu, item) {
	if (item == MENU_EXIT || !CheckPlayerBit(g_isConnected, id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new item_access, callback, info[2], name[32];
	menu_item_getinfo(menu, item, item_access, info, charsmax(info), name, charsmax(name), callback);
	
	new level = info[0];
	new db_levelMod[Stats];
	ArrayGetArray(levelModArray, level, db_levelMod);

#if defined USE_MONEY
	return (g_myLevel[id] < level || cs_get_user_money(id) < db_levelMod[COST]/* || CheckPlayerBit(g_myPower[id], level)*/) ? ITEM_DISABLED : ITEM_ENABLED;
#else
	return (g_myLevel[id] < level || csgo_get_user_dusts(id) < db_levelMod[COST]/* || CheckPlayerBit(g_myPower[id], level)*/) ? ITEM_DISABLED : ITEM_ENABLED;
#endif
}

public CmdManagePlayers(id) {
	if (!CheckPlayerBit(g_isConnected, id))
		return PLUGIN_HANDLED;

	if (!(get_user_flags(id) & ADMIN_ACCESS)) {
		client_print_color(id, print_team_default, "^4%s^1 You are not authorized to manage players level!", Tag);
		return PLUGIN_HANDLED;
	}

	new menu = menu_create("Select a player:", "MenuHandler");
	new iPlayers[32], iNum, i, player;
	new szUserID[32], szName[64];
	get_players(iPlayers, iNum);

	for (i = 0; i < iNum; i++) { 
		player = iPlayers[i];

		formatex(szName, charsmax(szName), "%s:\y Level:\r %d", g_playerName[player], g_myLevel[player]);
		formatex(szUserID, charsmax(szUserID), "%d", get_user_userid(player));
		menu_additem(menu, szName, szUserID);
	}

	menu_display(id, menu);
	return PLUGIN_HANDLED_MAIN;
}

public MenuHandler(id, menu, item) {
	if (item == MENU_EXIT || !CheckPlayerBit(g_isConnected, id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
   
	new item_access, callback, info[32], name[32];
	menu_item_getinfo(menu, item, item_access, info, charsmax(info), name, charsmax(name), callback);
	
	new userid = str_to_num(info);
	new player = find_player("k", userid);

	ChoosePlayer(id, player);
	return PLUGIN_HANDLED;
}

public ChoosePlayer(id, player) {
	new text[128], db_levelMod[Stats], info[3];
	formatex(text, charsmax(text), "Schimba-i lui \r%s\y nivelul in:", g_playerName[player]);
	new menu = menu_create(text, "SetLevelHandler");
	
	for (new level = 1; level <= g_maxLevel; level++) {
		ArrayGetArray(levelModArray, level, db_levelMod);
		formatex(text, charsmax(text), "Level \r%d\w (%d XP)", level, db_levelMod[XP]);
		
		info[0] = player;
		info[1] = level;
		info[2] = 0;
		menu_additem(menu, text, info);
	}
	menu_display(id, menu);
	return PLUGIN_HANDLED;
}

public SetLevelHandler(id, menu, item) {
	if (item == MENU_EXIT || !CheckPlayerBit(g_isConnected, id)) {
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new item_access, callback, info[3], name[32];
	menu_item_getinfo(menu, item, item_access, info, charsmax(info), name, charsmax(name), callback);

	new player = info[0];
	new levelToSet = info[1];

	client_print_color(player, print_team_default, "^4%s^1 Admin^3 %s^1 %s your level to^4 %d^1.", Tag, g_playerName[id], levelToSet < g_myLevel[player] ? "downgrade" : "upgrade", levelToSet);

	// reset power
	if (levelToSet < g_myLevel[player]) {
		for (new level = levelToSet - 1; level <= g_myLevel[player]; level++) {		// levelToSet - 1 ca sa resetez si puterea curenta
			if (CheckPlayerBit(g_myPower[player], level))
				ClearPlayerBit(g_myPower[player], level);

			if (CheckPlayerBit(g_myPowerActive[player], level))
				ClearPlayerBit(g_myPowerActive[player], level);
		}
	}
	
	// reset level
	g_myLevel[player] = levelToSet;

	// reset XP
	new db_levelMod[Stats];
	ArrayGetArray(levelModArray, levelToSet - 1, db_levelMod);
	g_myXP[player] = db_levelMod[XP];
	
	menu_destroy(menu);
	return PLUGIN_HANDLED;
}

public CheckUserLevel(id) {
	if (!CheckPlayerBit(g_isConnected, id) || g_myLevel[id] == g_maxLevel)
		return;

	new db_levelMod[Stats];
	new level = computeUserLevel(id);
	ArrayGetArray(levelModArray, level, db_levelMod);

	if (level != g_myLevel[id] || g_myXP[id] >= db_levelMod[XP]) {
		g_myLevel[id] = level;
		
		if (cvar_cache[xp_levelup_effects]) {
			new g_Color[3];
			g_Color[0] = random_num(0, 255); // r
			g_Color[1] = random_num(0, 255); // g
			g_Color[2] = random_num(0, 255); // b

			MakeFadeScreen(id, 1.5, g_Color, random_num(100, 200));
		}

		if (cvar_cache[xp_levelup_protection]) {
			fm_set_user_godmode(id, 1);
			set_task(1.0, "task_RemoveProtect", id);
		}

		client_print_color(id, print_team_default, "^3%s^1 Congratulations, ^4you have leveled up^1. Current level:^3 %d^1 !", Tag, level);
		if (g_myLevel[id] < g_maxLevel)
			client_print_color(id, print_team_default, "^3%s^1 Next XP:^4 %d^1 !", Tag, db_levelMod[XP]);

		new returnVal;
		ExecuteForward(g_fwdUserLevelUpdated, returnVal, id, level);
	}
}

stock MakeFadeScreen(id, const Float:Seconds, const color[3], const Alpha) {
	static g_MsgScreenFade = 0;
	if (!g_MsgScreenFade)
		g_MsgScreenFade = get_user_msgid("ScreenFade");

	message_begin(MSG_ONE, g_MsgScreenFade, _, id);
	write_short(floatround(4096.0 * Seconds, floatround_round));
	write_short(floatround(4096.0 * Seconds, floatround_round));
	write_short(0x0000);
	write_byte(color[0]);
	write_byte(color[1]);
	write_byte(color[2]);
	write_byte(Alpha);
	message_end();
}

public task_RemoveProtect(id)
	fm_set_user_godmode(id, 0);

#if defined SHOW_HUD
public task_ShowHUD(id) {
	id -= TASK_SHOWHUD;
	new db_levelMod[Stats];
	ArrayGetArray(levelModArray, g_myLevel[id], db_levelMod);

	if (CheckPlayerBit(g_isAlive, id)) {
		set_hudmessage(0, 255, 128, 0.02, 0.88, 0, 6.0, 1.1, 0.0, 0.0, -1);
		if (g_myLevel[id] == g_maxLevel)
			ShowSyncHudMsg(id, SyncHudMessage, "RANK: %s  -  LEVEL: %d  -  XP: %d", db_levelMod[RANK], g_maxLevel, g_myXP[id]);
		else
			ShowSyncHudMsg(id, SyncHudMessage, "RANK: %s  -  LEVEL: %d/%d  -  XP: %d/%d", db_levelMod[RANK], g_myLevel[id], g_maxLevel, g_myXP[id], db_levelMod[XP]);
	} else {
		static idSpec;
		idSpec = pev(id, pev_iuser2);

		if (CheckPlayerBit(g_isConnected, idSpec)) {
			ArrayGetArray(levelModArray, g_myLevel[idSpec], db_levelMod);

			set_hudmessage(255, 255, 255, -1.0, 0.87, 0, 6.0, 1.1, 0.0, 0.0, -1);
			ShowSyncHudMsg(id, SyncHudMessage, "Spectating: %s (%.1f HP)^nLevel: %d | XP: %d", g_playerName[idSpec], float(get_user_health(idSpec)), g_myLevel[idSpec], g_myXP[idSpec]);
		}
	}
}
#endif

public fnSaveXP(id) {
	new szVaultData[64];
	format(szVaultData, charsmax(szVaultData), "%i#%i#%i#", g_myXP[id], g_myPower[id], g_myPowerActive[id]);
	nvault_set(g_Vault, g_playerName[id], szVaultData);
	//nvault_close(g_Vault);
}

public fnLoadXP(id) {
 	new szVaultData[64], xp[10], power[10], power2[10];
	format(szVaultData, charsmax(szVaultData), "%i#%i#%i#", g_myXP[id], g_myPower[id], g_myPowerActive[id]);

	nvault_get(g_Vault, g_playerName[id], szVaultData, charsmax(szVaultData));
	replace_all(szVaultData, charsmax(szVaultData), "#", " ");

	parse(szVaultData, xp, charsmax(xp), power, charsmax(power), power2, charsmax(power2));
	g_myXP[id] = str_to_num(xp);
	g_myPower[id] = str_to_num(power);
	g_myPowerActive[id] = str_to_num(power2);
	//nvault_close(g_Vault);
}

// STOCK'S
stock set_user_xp(id, xp) {
	if (CheckPlayerBit(g_isConnected, id)) {
		if (xp != 0) {
			g_myXP[id] += xp;
			if (g_myXP[id] <= 0)
				g_myXP[id] = 0;
		}

		CheckUserLevel(id);
		fnSaveXP(id);
	}
}

stock computeUserLevel(id) {
	new currLevel = g_maxLevel, db_levelMod[Stats];
	for (new level = 1; level <= g_maxLevel; level++) {
		ArrayGetArray(levelModArray, level, db_levelMod);
		if (g_myXP[id] < db_levelMod[XP]) {
			currLevel = level;
			break;
		}
	}
	
	return currLevel;
}

stock fm_set_user_godmode(id, godmode = 0) {
	set_pev(id, pev_takedamage, godmode == 1 ? DAMAGE_NO : DAMAGE_AIM);
	return PLUGIN_HANDLED;
}
