#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Filehandle"
#define VERSION "1.0"
#define AUTHOR "Administrator"

new Array:blackListPlayers;
new playersCount;

enum _:BlacklistData {
	playerName[32],
	adminName[32]
};

new max_players;
new blackListData[BlacklistData];
new filename[256];

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say", "cmdSay");

	readPlayersFromBlacklist();

	// retinem intr-o variabila globala numarul de jucatori
	max_players = get_maxplayers();
}

public plugin_precache() {
	blackListPlayers = ArrayCreate(BlacklistData);
}

public plugin_end() {
	ArrayDestroy(blackListPlayers);
}

public client_authorized(id, const authid[]) {
	if (isUserInBlackList(id))
		server_cmd("kick #%d ^"You have no entry on server...^"", get_user_userid(id));
}

public readPlayersFromBlacklist() {
	get_configsdir(filename, charsmax(filename));
	format(filename, charsmax(filename), "%s/blacklist.txt", filename);

	new readdata[65];	// 32 name + 32 name + 1 space

	// deschidem fisierul, retinem adresa in pointerul file
	new file = fopen(filename, "r+");

	// cat timp nu am ajuns la EOF
	while (!feof(file)) {
		// citim linia curenta in readata
		fgets(file, readdata, charsmax(readdata));

		// eliminam spatiile albe
		trim(readdata);

		// daca avem primul caracter in fata numelui sau linia este empty, ignoram
		if (readdata[0] == ';' || !strlen(readdata))
			continue;

		// impartim textul in functie de spatti, ne intereseaza sa avem doua
		if (parse(readdata, blackListData[playerName], charsmax(blackListData[playerName]), blackListData[adminName], charsmax(blackListData[adminName])) != 2) {
			log_to_file("errors.txt", "[AMXX] Nu am putut delimita linia (%s). Este scrisa gresit.", readdata);
			continue;
		}

		// inseram in array numele
		ArrayPushArray(blackListPlayers, blackListData);
		playersCount++;
	}
	
	fclose(file);
}

stock bool:isUserInBlackList(const id) {
	if (id < 1 || id > max_players) {
		client_print(id, print_chat, "User is invalid!");
		return false;
	}
	
	new bool:userisinfile = false;

	// stocam numele jucatorului
	new targetName[32];
	get_user_name(id, targetName, charsmax(targetName));

	// iteram prin array
	for (new i = 0; i < playersCount; i++) {
		// luam element cu element din array si il stocam in blackListData
		ArrayGetArray(blackListPlayers, i, blackListData);

		// avem match?
		if (equal(blackListData[playerName], targetName)) {
			userisinfile = true;
			break;
		}
	}

	return userisinfile;
}

public cmdSay(id) {
	new szSaid[192]
	read_args(szSaid, charsmax(szSaid));
	remove_quotes(szSaid);
	
	if (contain(szSaid, "/blacklist") != -1) {
		if (!is_user_admin(id)) {
			client_print(id, print_chat, "You don't have access!");
			return PLUGIN_CONTINUE;
		}

		new _adminName[32];
		get_user_name(id, _adminName, charsmax(_adminName));

		new targetName[32];
		copy(targetName, charsmax(targetName), szSaid[11]);
		
		// cautam jucatorul tinta
		new player = find_player_ex(FindPlayer_MatchNameSubstring, targetName);
		
		// apelam functia nostra de verificare a jucatorului
		if (isUserInBlackList(player)) {
			client_print(id, print_chat, "User [%s] is already in the blacklist!", targetName);
		} else {
			// deschide fisierul, retine pointerul in file si insearaeza pe ultima linie
			new file = fopen(filename, "w+");

			// muta cursorul la sfarsitul fisierului
			fseek(file, 0, SEEK_END);

			// scrie in fisier (inseareaza si un \n newline pt ca fprintf nu inseareaza automat)
			fprintf(file, "^n^"%s^" ^"%s^"", targetName, _adminName);

			// inchidem fisierul
			fclose(file);

			// actualizam si array-ul nostru pentru ca nu deschidedm si inchidem un fisier de n ori, e mult mai fiabil sa retinem datele intr-un array
			// populam variabilele din array-ul de pe ultima pozitie
			copy(blackListData[playerName], charsmax(blackListData[playerName]), targetName);
			copy(blackListData[adminName], charsmax(blackListData[adminName]), _adminName);
			
			// inseram
			ArrayPushArray(blackListPlayers, blackListData);
			playersCount++;
		}

		// blocam executia aici (return 2 e folosit pt a nu afisa pe ecran comanda executata si celorlalti jucatori)
		return PLUGIN_HANDLED_MAIN;
	}

	return PLUGIN_CONTINUE;
}
