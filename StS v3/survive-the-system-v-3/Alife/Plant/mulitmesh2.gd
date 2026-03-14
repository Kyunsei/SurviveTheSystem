extends MultiMeshInstance3D

var instance_number := 0
var shadow

var id_to_slot := {}
var slot_to_id := {}

func init():
	instance_number = 0
	multimesh.visible_instance_count = instance_number 
	id_to_slot = {}
	slot_to_id = {}
	
func _ready() -> void:
	multimesh.instance_count = 1000000
	if has_node("shadow"):
		shadow = $shadow
		shadow.multimesh.instance_count = 1000000

func draw_all_grass(id, pos, state, alive, active):
	var slot= instance_number
	id_to_slot[id] = instance_number
	slot_to_id[instance_number] = id	
	
	var i_scale = Vector3.ONE * clamp(float(state) / 5, 0.2, 1)
	var draw_pos = pos
	if active == 0:
		draw_pos.y = -100
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(i_scale), draw_pos))
	if alive == 0:
		multimesh.set_instance_color(slot, Color(0.27, 0.27, 0.27, 1.0))
	else:
		multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))
	instance_number += 1
	#multimesh.visible_instance_count = instance_number
	if shadow:
		shadow.multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * i_scale), draw_pos))
		shadow.multimesh.visible_instance_count = instance_number
		shadow.multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))

func update_drawn_grass(id_array, pos_array, state_array, alive_array, active_array):
	
	if !id_to_slot.has(id_array):
		#print("strange: grass need update but not instantiated (yet?)")
		return
	var slot = id_to_slot[id_array]
	
	
	var i_scale = Vector3.ONE
	var pos = Vector3.ZERO
	#for i in range(id_array.size()):
	pos = pos_array#[i]
	i_scale = Vector3.ONE * clamp(float(state_array)/5,0.2,1)  # I guess it should be somthing else.. like a size variable
	if active_array == 0:#[i] == 0:
		pos.y = -100 #MAYBE THIS NEED TO CHANGE TOO
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(i_scale), pos))
	multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))	
	if alive_array==0:
		multimesh.set_instance_color(slot, Color(0.249, 0.082, 0.08, 1.0))
	else:
		multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))
	if shadow:
		shadow.multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * i_scale), pos))
		shadow.multimesh.visible_instance_count = instance_number
		shadow.multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))

func draw_new_grass(id_array, pos_array):# state_array, alive_array):
	var slot= instance_number
	id_to_slot[id_array] = instance_number
	slot_to_id[instance_number] = id_array	
	
	
	
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
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(i_scale), pos))
	multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))

	instance_number += 1
	#print(instance_number)
	if shadow:
		shadow.multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * i_scale), pos))
		shadow.multimesh.visible_instance_count = instance_number
		shadow.multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))

	

func remove_grass(id):
	#return
	if !id_to_slot.has(id):	
		print("remove failed no ID registered?")
		return

	var slot = id_to_slot[id]
	var last_slot = instance_number - 1
	
	if slot != last_slot:
		# Move last transform into removed slot
		multimesh.set_instance_transform(
			slot,
			multimesh.get_instance_transform(last_slot)
		)
		if shadow:
			shadow.multimesh.set_instance_transform(
				slot, multimesh.get_instance_transform(last_slot))
		
		# Update mappings
		var moved_id = slot_to_id[last_slot]
		id_to_slot[moved_id] = slot
		slot_to_id[slot] = moved_id
	
	# Remove mappings
	id_to_slot.erase(id)
	slot_to_id.erase(last_slot)
	
	instance_number -= 1
	multimesh.visible_instance_count = instance_number
	if shadow:
		shadow.multimesh.visible_instance_count = instance_number

	
