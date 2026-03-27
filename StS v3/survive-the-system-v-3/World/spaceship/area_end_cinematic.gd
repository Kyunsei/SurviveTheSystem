extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass

func _process(_delta):
	pass
	pass
	pass
@rpc("any_peer", "call_remote")
func tween_that_shit(fade_time: float, color: Color):
	print("worked")
	var end_canvas = get_parent().get_parent().get_parent().get_node("end_canvas")
	var text = end_canvas.get_node("VBoxContainer").get_children()
	for child in text :
		print(child)
		var start_color = color
		start_color.a = 0.0
		child.modulate = start_color
		var tween = create_tween()
		tween.tween_property(child, "modulate:a", 1.0, fade_time) # fade in
		tween.tween_interval(1.0) # wait
		tween.tween_property(child, "modulate:a", 0.0, fade_time) # fade out
		#tween.tween_property(child, "modulate:a", 1.0, fade_time)





func interact(player, state:bool):
	#if state == false:
		#player.show_label_above_player.rpc_id(int(player.name),1, Color(1.0, 1.0, 1.0, 1.0), 2.0,"Special","You did not finish your mission!")
		#return
	#else:
		var player_list = player.get_parent().player_array
		var spaceship = player.get_parent().get_parent().get_node("SPACESHIP")
		var end_canvas = spaceship.get_parent().get_node("end_canvas")
		#var main_game = spaceship.get_parent()
		var spaceship_height = spaceship.global_position.y
		var all_above = true
		for p in player_list:

			if p.global_position.y < spaceship_height:
				all_above = false
				break
		if all_above:
			spaceship.block_entrance()
			for p in player_list:
				p.show_label_above_player.rpc_id(int(p.name),1, Color(1.0, 1.0, 1.0, 1.0), 5.0,"Special","The Cat Empire thank you for your effort")
			print("Are you sure you want to end the game?")
			print("Make a confirmation here")
			sync_button_pressed.rpc()
			var selfe = player.get_parent().get_parent().get_node("SPACESHIP").get_node("endgame_console").get_node("area_end_cinematic")
			selfe.global_position = Vector3(1000,1000,1000)
			var main_game = player.get_parent().get_parent()
			var end_animater = main_game.get_node("endgameanimation1")
			var end_animater2 = main_game.get_node("endgameanimation2")
			end_animater.play("collector_retrieval1")
			end_animater2.play("stairs_retracting")
			await get_tree().create_timer(5.0).timeout
			for p in player_list:
				p.show_label_above_player.rpc_id(int(p.name),1, Color(1.0, 1.0, 1.0, 1.0), 7.0,"Special","Time to go back to your root")
			#await end_animater2.animation_finished
			#end_animater2.play("retracted")
			#await end_animater.animation_finished
			#end_animater.play("collector_retrieved")
			await get_tree().create_timer(18.0).timeout
			for p in player_list:
				p.hide_inventory.rpc_id(int(p.name))
			var alife_manager = get_parent().get_parent().get_parent().get_node("Alife manager")
			#spaceship.get_node("Stairs").hide()
			var player_list2 = alife_manager.player_array
			spaceship.get_node("Stairs").hide()
			for p in player_list2:
				p.change_player_energy.rpc_id(1,1000000.0)
				change_camera.rpc_id(int(p.name))
			await get_tree().create_timer(3.0).timeout
			end_animater.play("ship_going_away")
			await get_tree().create_timer(5.0).timeout
			for p in player_list2:
				end_canvas.show()
				p.go_to_position.rpc_id(int(p.name), Vector3(10000,10000,-10000))
				tween_that_shit.rpc_id(int(player.name),5.0, Color(1.0,1.0,1.0,1.0))

	
	

@rpc("any_peer","call_remote")
func change_camera():
	var main_game = get_parent().get_parent().get_parent()
	var camera = main_game.get_node("endgame_camera")
	camera.current = true
	


@rpc("any_peer")
func sync_button_pressed():
	#var alife_manager = get_parent().get_parent().get_parent().get_node("Alife manager")
	#var player_list = alife_manager.player_array
	#for p in player_list:
		var button_mat = get_parent().get_parent().get_parent().get_node("SPACESHIP").get_node("endgame_console").get_node("MainBoard").get_node("ButtonPanel").get_active_material(0)
		button_mat.albedo_color = Color(0.0,1.0,0.0)
