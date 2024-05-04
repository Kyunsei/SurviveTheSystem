extends Node2D




var energy = 10#10.
var maxenergy = 50.
var colormax = Color(0.3, 0.2, 0.1, 1)
var colormin = Color(0.8, 0.6, 0.4, 1)


# Called when the node enters the scene tree for the first time.
func _ready():
	Update()
	UpdatePhysics()
	
	pass # Replace with fadunction body.

func UpdatePhysics():
	pass
	#$Dirt/CollisionShape2D.shape.size = Vector2(World.tile_size,World.tile_size)
	#$Dirt/ColorRect.size = Vector2(World.tile_size,World.tile_size)
	#Vector2(size1,size1)*1.1 # $RigidBody2D/CollisionShape2D.shape.size *1.2#.get_size()
	#$Area2D/CollisionShape2D.scale = $RigidBody2D/Sprite2D.scale 


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	$Label.text = str(position/World.tile_size)
	#$Dirt/Label.text= str(energy)

	pass

func Update():

	var x = min(1, energy/maxenergy )
	var col = lerp(colormin, colormax, x)
	#$Dirt/ColorRect.color =  col

'''

func _on_rigid_body_2d_body_entered(body):
	if body.has_method("energyCosumption"):
		body.tiles_array.append(self)
		#print(body.get_parent().tiles_array)
	if body.name.match("Player"):
		body.tiles_array.append(self)
		


func _on_rigid_body_2d_body_exited(body):
	if body.has_method("energyCosumption"):
		body.tiles_array.erase(self)
		#print(body.get_parent().tiles_array)
	if body.name.match("Player"):
		body.tiles_array.erase(self)
		
'''
