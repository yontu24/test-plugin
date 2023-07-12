#include <amxmodx>

#define MAX_LINE_CHARS    128 // presupunem ca o linie are maxim 128 de caractere
#define MAX_READ_LINES    100    // presupunem ca vom citi maxim 100 de linii

new const FILE_PATH[] = "addons/amxmodx/configs/skins/skins.ini";

new lines[MAX_READ_LINES][MAX_LINE_CHARS]; 
new totalReadLines = 0;    // cate linii am citit

public plugin_init() {

    // ...
    readLinesFromFile();
    
    register_clcmd("say /menu", "cmdMenu");
    // ...
}

public readLinesFromFile() {
    new Trie:uniqueTypes = TrieCreate();

    if (file_exists(FILE_PATH)) {
        new fp = fopen(FILE_PATH, "r+");
        new line[MAX_LINE_CHARS], type[5], value;
        
        while (!feof(fp)) {
            fgets(fp, line, MAX_LINE_CHARS - 1);
            trim(line);
            
            if (line[0] == ';' || !line[0])
                continue;

            parse(line, type, charsmax(type));

            if (TrieGetCell(uniqueTypes, type, value))
                continue;

            // copies in lines linia line
            copy(lines[totalReadLines], MAX_LINE_CHARS - 1, line);
            
            TrieSetCell(uniqueTypes, type, totalReadLines);
            totalReadLines++;

            // am citit cat ne-am propus si iesim fortat
            if (totalReadLines == MAX_READ_LINES)
                break;
        }

        fclose(fp);
    }

    TrieClear(uniqueTypes);
}

public cmdMenu(id) {
    new menu = menu_create("SKINS", "mainHandler")

    for (new i; i < totalReadLines; i++)
        menu_additem(menu, lines[i]);

    menu_display(id, menu);
    return PLUGIN_CONTINUE;
}
