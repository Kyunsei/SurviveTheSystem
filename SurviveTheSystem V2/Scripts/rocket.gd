extends CharacterBody2D


var isPlayerNear: bool = false

func _on_area_2d_body_entered(body):
	if body == Life.player:
		isPlayerNear = true


func _on_area_2d_body_exited(body):
	if body == Life.player:
		isPlayerNear = false
		$Control.hide()
		 # Replace with function body.

func _input(event):
	if event.is_action_pressed("interact"):
		if isPlayerNear:
			Call_endGame()

func Call_endGame():
	$Control.show()
	$Control.global_position = Life.player.global_position + Vector2(0,-128)

func _on_button_yes_pressed():
	#get_tree().paused = true
	get_tree().change_scene_to_file("res://Scenes/Window_end_game.tscn")


func _on_button_no_pressed():
	$Control.hide()
