#include <amxmodx>

#define MAX_LINE_CHARS    128 // presupunem ca o linie are maxim 128 de caractere
#define MAX_READ_LINES    100    // presupunem ca vom citi maxim 100 de linii

new const FILE_PATH[] = "addons/amxmodx/configs/skins.ini";

enum _:INFO {
    name[32],    // cam atatea caractere ar trebui sa aiba un nume
    price        // asta e un int
};

new totalReadLines = 0;    // cate linii am citit

new Trie:uniqueTypes;

public plugin_init() {

    // ...
    readLinesFromFile();
    
    register_clcmd("say /menu", "cmdMenu");
    // ...
}

public readLinesFromFile() {
    uniqueTypes = TrieCreate();

    if (file_exists(FILE_PATH)) {
        new fp = fopen(FILE_PATH, "r+");
        new line[MAX_LINE_CHARS];

        // creez un array ce va contine doar name + price (asta va fi doar un element din array-ul lines, linia 13)
        new skinName[32], skinPrice[6]; // 6 caractere pt ca vom considera ca numarul maxim ar fi de 5 cifre
        new lines[MAX_READ_LINES][INFO];
        
        while (!feof(fp)) {
            fgets(fp, line, MAX_LINE_CHARS - 1);
            trim(line);
            
            if (line[0] == ';' || !line[0])
                continue;

            // parsam numele si pretul
            parse(line, skinName, charsmax(skinName), skinPrice, charsmax(skinPrice));

            // copiez in lines (in array) cele 2 valori
            copy(lines[totalReadLines][name], charsmax(skinName), skinName);

            // inseram si pretul aici
            lines[totalReadLines][price] = str_to_num(skinPrice);
            
            // incrementam numarul de valori (name + price) in array
            totalReadLines++;

            // am citit cat ne-am propus si iesim fortat
            if (totalReadLines == MAX_READ_LINES)
                break;
        }

        fclose(fp);

        // abia dupa ce citim din fisier, putem sa sortam array-ul nostru si sa copiem tot array-ul in Trie
        // putem face asta o singura data
        // vom folosi aceasta functia pt ca array-ul nostru e multidimensional
        SortCustom2D(lines, totalReadLines, "sortFunction");

        // odata sortat, putem sa ne creeam Trie-ul
        // vom folosi TrieSetArray pt ca in trie vom insera un array la valoare
        // el va arata ceva de genul:
        // 
        // {
        //     "ak47": { "ak47", 1000 },
        //     "m4a1": { "m4a1", 20000 }
        // }
        // 
        // dupa cum observi, la cheie vom folosi numele armei, 
        // practic nu vom putea avea duplicate chiar daca in 
        // fisier exista mai multe linii care au acelasi nume la arma
        for (new i = 0; i < totalReadLines; i++)
            TrieSetArray(uniqueTypes, lines[i][name], lines[i], INFO, false);

        // vom folosi tagul INFO (enumeratia) ca si size pt ca in INFO avem nume (32 caractere) + 1 int (1 caracter), deci 33 caractere
    }
}

/**
 * in functia de sortare ai voie sa returnezi
 * doar 3 valori: -1, 0, 1. Mai jos ai un exemplu

 * in acest fel, il sortezi crescator;
 * daca vrei descrescator, inversezi -1 cu 1 si 1 cu -1

 * putem sa indexam perechile din INFO in elem1 si elem2
 */
public sortFunction(const elem1[], const elem2[], const array[], data[], data_size) {
    if (elem1[price] > elem2[price])
        return -1;    // descrescator: 1
    else if (elem1[price] == elem2[price])
        return 0;
    
    // elem1 < elem2
    return 1;      // descrescator: -1
}

/**
 * Aici e aceeasi poveste: avem nevoie de un iterator ca sa putem itera prin trie
 * Insa, vom folosi TrieIterGetArray ca sa extragem array-ul valoare din cheia curenta
 */
public cmdMenu(id) {
    new temp[128];	// 128 cred ca e suficient
    new menu = menu_create("\w=> \yRang-uri \w|| \rPreturi", "mainHandler")

    new lineInfo[INFO];
    new TrieIter:iterator = TrieIterCreate(uniqueTypes);
    while (!TrieIterEnded(iterator)) {
        TrieIterGetArray(iterator, lineInfo, INFO);

        formatex(temp, charsmax(temp), "\w===> \y%s \w||\r %d EUR", lineInfo[name], lineInfo[price]);
        menu_additem(menu, temp, lineInfo[name]);	// stocam cheia in item ca sa putem accesa array-ul in callback-ul meniului

        TrieIterNext(iterator);
    }
    TrieIterDestroy(iterator);

    menu_display(id, menu);
    return PLUGIN_CONTINUE;
}


public mainHandler(id, menu, item) {
    if(!is_user_connected(id)) {
        menu_destroy(menu);
        return PLUGIN_HANDLED;
    }

    // extragem cheia ca sa putem accesa array-ul din Trie
    new skinInfo[INFO];
    menu_item_getinfo(menu, item, _, skinInfo[name], charsmax(skinInfo[name]));

    // putem sa folosim aceeasi variabila ca si valoare la cheie, 
    // astfel skinInfo va fi outputul unde retinem array-ul valoare
    TrieGetArray(uniqueTypes, skinInfo[name], skinInfo, INFO);

    client_print_color(id, print_team_default, "^4[SKINS]^1 Ai selectat arma^3 %s^1 care costa^4 %d$^1.", skinInfo[name], skinInfo[price]);

    menu_destroy(menu);
    return PLUGIN_HANDLED;
}
