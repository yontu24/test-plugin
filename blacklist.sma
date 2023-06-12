#include <amxmodx>
#include <amxmisc>

#define PLUGIN "Filehandle"
#define VERSION "1.0"
#define AUTHOR "Administrator"

new filename[256]

new bool:userisinfile = false


public plugin_init() {
    register_plugin(PLUGIN, VERSION, AUTHOR)
    
    register_clcmd("say", "cmdSay")
    
    get_configsdir(filename,255)
    format(filename,255,"%s/blacklist.txt",filename)
}

public cmdSay(id) {
	new szSaid[192]
	read_args(szSaid, charsmax(szSaid))
	remove_quotes(szSaid)
	
	if(contain(szSaid, "/blacklist") != -1) {
		new target[32],txtlen, readdata[128], parsedname[32]
		copy(target, sizeof(target)-1, szSaid[11])
		new player = cmd_target(id, target, 2)
		
		if(player) {
			new line = 0
			while(!read_file(filename,line++,readdata,127,txtlen))
			{
				new name[32]
				parse(filename,parsedname,31)
				get_user_name(id, name, charsmax(name))
				if(equal(name, parsedname)) {
					client_print(id, print_chat, "User [%s] is already in the blacklist!", parsedname)
					userisinfile = true
				}
			}
			if(userisinfile == false) {
				new writedata[128]
				formatex(writedata,127,"%s",player)
				write_file(filename, writedata)
			}
		}
		else {
			client_print(id, print_chat, "User is invalid")
		}
	}
}