extends Area3D

var player

var step = 3 #0
var time_to_load = 10
var current_time = 0

func display_text(dialogue_box, text):
	dialogue_box.show()
	dialogue_box.show_text(text)




			
func interact(p):
	player = p
	if not player.dialogue_box.button_pressed.is_connected(_on_next):
		player.dialogue_box.button_pressed.connect(_on_next)
	display_text(p.dialogue_box, "Welcome Catraunaute! \n We need you to collect bioressources for the magnificient catempire! \n Are you READY ?!!?!")
	player.dialogue_box.show_button()


func loading():
	if step == 1:
		for i in 10:
			await get_tree().create_timer(1.0).timeout
			display_text(player.dialogue_box, "Loading World..." +  str(i*10) +"%")
		
	
		step += 1
		change_server_simulation_speed.rpc_id(1,0.001)
		cooling()

func cooling():
	if step == 2:
		for i in 10:
			await get_tree().create_timer(1.0).timeout
			display_text(player.dialogue_box, "Cooling down World..." +  str(i*10) +"%")
		
		

		step += 1
		display_text(player.dialogue_box, "World Ready")
		#GlobalSimulationParameter.WorldReady = true
		set_world_readiness.rpc(true)
		player.dialogue_box.show_button()


func _on_next():
	if GlobalSimulationParameter.WorldReady == true:
		player.position = Vector3(0,1,0)
		step = 0
		
	else:
		if step == 0:
			display_text(player.dialogue_box, "Loading World...0%")
			step += 1
			change_server_simulation_speed.rpc_id(1,0.5)
			player.dialogue_box.hide_button()
			loading()
		if step == 3:
			player.position = Vector3(0,1,0)
			step = 0
	
@rpc("any_peer","call_remote")
func change_server_simulation_speed(value):
	GlobalSimulationParameter.simulation_speed = value


@rpc("any_peer","call_remote")
func set_world_readiness(yesorno):
		GlobalSimulationParameter.WorldReady = yesorno



'@rpc("any_peer","call_remote")
func get_world_readiness(yesorno):
		GlobalSimulationParameter.WorldReady = yesorno'
