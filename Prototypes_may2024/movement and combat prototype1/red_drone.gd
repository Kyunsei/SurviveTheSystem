extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready():
	self.position = Vector2(600, 600)
	#_on_area_2d_area_entered(area)
	#get_node("Char1")
	_plasma()
var player_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
var direction = Vector2.DOWN
func _process(delta):
	var player_node = get_tree().root.get_node("main/Char1")
	player_position = player_node.position
	#print(player_position)
	direction = player_position -self.position
	
	
	if int(direction.x) < 0:
		position.x -= 0.7
	elif int(direction.x) > 0:
		position.x += 0.7
	elif int(direction.y) < 0:
		position.y -= 0.7
	elif int(direction.y) > 0:
		position.y += 0.7
	#get_node("Char1")
	#if Char1.position

func _on_area_2d_area_entered(area):
		if area.visible and area.name == "SwordDown":
			position -= Vector2(direction.normalized()*100)
			#print("You've pushed the red drone.")
			
			#_animated_sprite.stop()
			
@export var rotation_speed = 1.5
var plasma_scene = preload("res://plasma_scene.tscn")
func _plasma():
	if int(direction.x) > -5 and int(direction.x) < 5 or int(direction.y) > -5 and int(direction.y) < 5  :
	#	get_node("plasma_scene")
		plasma_scene.instantiate()
		var plasma = plasma_scene.instantiate()
		plasma.position = self.position
		plasma.look_at(direction)
		plasma.velocity = direction.normalized()*400
		get_tree().root.add_child(plasma)
		#print("The red drone shot a plasma.")
		await get_tree().create_timer(1).timeout
		_plasma()
	else :
		await get_tree().create_timer(0.01).timeout
		_plasma()
		


func _on_red_plasma_shoot(bullet, direction, location):
		pass
