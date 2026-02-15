extends Area3D

var player

var step = 0
var time_to_load = 10
var current_time = 0

func display_text(dialogue_box, text):
	dialogue_box.show()
	dialogue_box.show_text(text)


func _process(delta: float) -> void:
	if step == 1:
		current_time += delta
		display_text(player.dialogue_box,  str(floor(current_time)) +"%")
		if current_time >= time_to_load:
			step += 1
			current_time = 0
			change_server_simulation_speed.rpc_id(1,0.001)

	if step == 2:
		current_time += delta
		display_text(player.dialogue_box,  str(floor(current_time)) +"%")
		if current_time >= time_to_load:
			step += 1
			current_time = 0
			display_text(player.dialogue_box, "World Ready")
func interact(p):
	player = p
	if not player.dialogue_box.button_pressed.is_connected(_on_next):
		player.dialogue_box.button_pressed.connect(_on_next)
	display_text(p.dialogue_box, "Welcome Catraunaute! \n We need you to collect bioressources for the magnificient catempire! \n Are you READY ?!!?!")


func _on_next():
	if step == 0:
		display_text(player.dialogue_box, "Loading World...0%")
		step += 1
		change_server_simulation_speed.rpc_id(1,0.5)
	if step == 3:
		player.position = Vector3(0,1,0)
		step = 0
	
@rpc("any_peer","call_remote")
func change_server_simulation_speed(value):
	GlobalSimulationParameter.simulation_speed = value
