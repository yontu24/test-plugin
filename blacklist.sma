#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Filehandle"
#define VERSION "1.0"
#define AUTHOR "Administrator"

new filename[256], bool:userisinfile = false;

public plugin_init() {
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say", "cmdSay");
	
	get_configsdir(filename, 255);
	format(filename, 255, "%s/blacklist.txt", filename);
}

public cmdSay(id) {
	new szSaid[192]
	read_args(szSaid, charsmax(szSaid));
	remove_quotes(szSaid);
	
	if (contain(szSaid, "/blacklist") != -1) {
		new targetName[32];
		copy(targetName, charsmax(targetName), szSaid[11]);
		
		// cautam jucatorul tinta
		new player = find_player_ex(FindPlayer_MatchNameSubstring, targetName);
		
		// avem un ID valid
		if (player) {
			// reutilizam variabila targetName unde stocam numele jucatorului
			get_user_name(player, targetName, charsmax(targetName));

			new readdata[32], parsedname[32];

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

				// impartim textul in functie de spatti, daca dupa cele 32 de caractere exista alt cuvant, aruncam eroare
				if (parse(readdata, parsedname, charsmax(parsedname)) != 1) {
					log_to_file("errors.txt", "[AMXX] Nu am putut delimita linia (%s). Este scrisa gresit.", readdata);
					continue;
				}

				// am gasit jucatorul?
				if (equal(targetName, parsedname)) {
					client_print(id, print_chat, "User [%s] is already in the blacklist!", parsedname)
					userisinfile = true;

					// odata ce l-am gasit, nu mai are rost sa citim urmatoarele linii, deci iesim fortat din loop
					break;
				}
			}

			// inchidem fisierul
			fclose(file);

			// daca nu l-am gasit in fisier, il adaugam
			if (!userisinfile) {
				// scriem in fisier numele acestuia 
				write_file(filename, targetName);
			}
		}
		// daca am gresit numele acestuia, sau utilizatorul nu exista, afisam mesaj corespunzator
		else
			client_print(id, print_chat, "User is invalid");

		// blocam executia aici (return 2 e folosit pt a nu afisa pe ecran comanda executata si celorlalti jucatori)
		return PLUGIN_HANDLED_MAIN;
	}

	return PLUGIN_CONTINUE;
}
