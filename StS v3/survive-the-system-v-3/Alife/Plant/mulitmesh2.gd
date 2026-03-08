extends MultiMeshInstance3D

var instance_number := 0
var shadow


func init():
	instance_number = 0
	multimesh.visible_instance_count = instance_number 

func _ready() -> void:
	multimesh.instance_count = 1000000
	if has_node("shadow"):
		shadow = $shadow
		shadow.multimesh.instance_count = 1000000

func draw_all_grass(id, pos, state, alive, active):
	var i_scale = Vector3.ONE * clamp(float(state) / 5, 0.2, 1)
	var draw_pos = pos
	if active == 0:
		draw_pos.y = -100
	multimesh.set_instance_transform(id, Transform3D(Basis().scaled(i_scale), draw_pos))
	if alive == 0:
		multimesh.set_instance_color(id, Color(0.27, 0.27, 0.27, 1.0))
	else:
		multimesh.set_instance_color(id, Color(1.0, 1.0, 1.0, 1.0))
	instance_number += 1
	#multimesh.visible_instance_count = instance_number
	if shadow:
		shadow.multimesh.set_instance_transform(id, Transform3D(Basis().scaled(Vector3.ONE * i_scale), draw_pos))
		shadow.multimesh.visible_instance_count = instance_number
		shadow.multimesh.set_instance_color(id, Color(1.0, 1.0, 1.0, 1.0))

func update_drawn_grass(id_array, pos_array, state_array, alive_array, active_array):
	var i_scale = Vector3.ONE
	var pos = Vector3.ZERO
	#for i in range(id_array.size()):
	pos = pos_array#[i]
	i_scale = Vector3.ONE * clamp(float(state_array)/5,0.2,1)  # I guess it should be somthing else.. like a size variable
	if active_array == 0:#[i] == 0:
		pos.y = -100 #MAYBE THIS NEED TO CHANGE TOO
	multimesh.set_instance_transform(id_array, Transform3D(Basis().scaled(i_scale), pos))
	multimesh.set_instance_color(id_array, Color(1.0, 1.0, 1.0, 1.0))	
	if alive_array==0:
		multimesh.set_instance_color(id_array, Color(0.27, 0.27, 0.27, 1.0))
	else:
		multimesh.set_instance_color(id_array, Color(1.0, 1.0, 1.0, 1.0))
	if shadow:
		shadow.multimesh.set_instance_transform(id_array, Transform3D(Basis().scaled(Vector3.ONE * i_scale), pos))
		shadow.multimesh.visible_instance_count = instance_number
		shadow.multimesh.set_instance_color(id_array, Color(1.0, 1.0, 1.0, 1.0))

func draw_new_grass(id_array, pos_array):# state_array, alive_array):
	var i_scale = Vector3.ONE * 0.2
	var pos = Vector3.ZERO
	#print(id_array)
	#for i in range(id_array.size()):
		#print(pos_array)
	pos = pos_array
	#i_scale = Vector3.ONE * clamp(float(state_array[i])/5,0.2,1)  # I guess it should be somthing else.. like a size variable

	#if state_array[i] == 0:
	#	pos.y = 1#-100
	#multimesh.set_instance_visible(i, true)
	multimesh.set_instance_transform(id_array, Transform3D(Basis().scaled(i_scale), pos))
	multimesh.set_instance_color(id_array, Color(1.0, 1.0, 1.0, 1.0))

	instance_number += 1
	#print(instance_number)
	if shadow:
		shadow.multimesh.set_instance_transform(id_array, Transform3D(Basis().scaled(Vector3.ONE * i_scale), pos))
		shadow.multimesh.visible_instance_count = instance_number
		shadow.multimesh.set_instance_color(id_array, Color(1.0, 1.0, 1.0, 1.0))

	

func remove_grass(id_array):
	#var off_transform := Transform3D(Basis(), Vector3(-100, -100, -100))
	#for i in id_array:
		#multimesh.set_instance_visible(i, false)
	multimesh.set_instance_color(id_array, Color(0.0, 0.0, 0.0, 1.0))
	if shadow:
		shadow.multimesh.set_instance_color(id_array, Color(0.0, 0.0, 0.0, 1.0))

	
	
