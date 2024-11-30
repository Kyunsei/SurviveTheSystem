extends Node

#add some value for saving 
var achievement_dic = {
	"hunger_death": 0,
	"age_death": 0,
	"fall_death": 0,
	"dammage_death": 0,
	"eat_death": 0,
}


#NOt in USE yet
var char_unlock = {
	"cat": 1,
	"planty": 0
}


func Save_achievement():
	var save_file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	var json_string = JSON.stringify(achievement_dic)
	save_file.store_line(json_string)

func Load_achievement():
	if not FileAccess.file_exists("user://savegame.save"):
		return # Error! We don't have a save to load.
		
	var save_file = FileAccess.open("user://savegame.save", FileAccess.READ)
	
	while save_file.get_position() < save_file.get_length():
		var json_string = save_file.get_line()
		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue

		# Get the data from the JSON object.
		achievement_dic = json.data

		


