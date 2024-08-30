extends Control

var scene_to_load = "res://Scenes//main_scene.tscn"
func _ready():
	ResourceLoader.load_threaded_request(scene_to_load) 


func _process(delta):
	var progress = []
	ResourceLoader.load_threaded_get_status(scene_to_load, progress)
	$ProgressBar.value = progress[0]*100
	
	if progress[0] == 1:
		var packed_scene = ResourceLoader.load_threaded_get(scene_to_load)
		get_tree().change_scene_to_packed(packed_scene)
