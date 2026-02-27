extends MultiMeshInstance3D


var id_to_slot := {}
var slot_to_id := {}
var instance_number := 0
var shadow
@export var max_energy = 10

func init():
	id_to_slot = {}
	slot_to_id = {}
	instance_number = 0

func _ready() -> void:
	multimesh.instance_count = 100000
	if has_node("shadow"):
		shadow = $shadow
		shadow.multimesh.instance_count = 100000

'func draw_all_grass(grass_dict):
	instance_number = 0
	id_to_slot.clear()
	slot_to_id.clear()
	#multimesh.visible_instance_count = grass_dict.size() 
	for g in grass_dict.values():
				var slot = instance_number
				id_to_slot[g["ID"]] = slot
				slot_to_id[slot] = g["ID"]
				
				multimesh.set_instance_transform(slot, Transform3D(Basis(), g["position"]))

				instance_number += 1
	multimesh.visible_instance_count = instance_number
	
var instance_data: Array = []  # mirrors multimesh slots'


func update_drawn_grass(g):
	#var ID = gen[0]
	var current_energy = g["current_energy"]
	#if id_to_slot.size() > g["ID"]:
	if !id_to_slot.has(g["ID"]):
		print("strange")
		return
	var slot = id_to_slot[g["ID"]]
	#var current_transform = multimesh.get_instance_transform(slot)
	var newscale = clamp(current_energy /max_energy,0.25,1)
		#newtransform.origin =  g["position"] #Vector3(slot * 2.0, 0, 0)
	#current_transform.basis = Basis().scaled(Vector3.ONE * newscale)
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * newscale),  g["position"]))
	if g["Alive"]==0:
		multimesh.set_instance_color(slot, Color(0.164, 0.164, 0.164, 1.0))
	else:
		multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))

	if shadow:
		shadow.multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * newscale), g["position"]))
'if abs(last_scale[id] - new_scale) > 0.05:
	update_transform()'


func draw_new_grass(g):
	var slot = instance_number
	
	id_to_slot[g["ID"]] = slot
	slot_to_id[slot] = g["ID"]	
	var newscale = clamp(g["current_energy"] /max_energy,0.25,1)
	var pos = g["position"]
	#current_transform.basis = Basis().scaled(Vector3.ONE * newscale)
	if g["current_life_state"] == 0:
		pos.y = -100
		
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * newscale), pos))
	if g["Alive"]==0:
		multimesh.set_instance_color(slot, Color(0.164, 0.164, 0.164, 1.0))
	else:
		multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))

	instance_number += 1
	multimesh.visible_instance_count = instance_number 

	
	if shadow:
		shadow.multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * newscale), pos))
		shadow.multimesh.visible_instance_count = instance_number


func remove_grass(g):
	if !id_to_slot.has(g["ID"]):	
		return

	var slot = id_to_slot[g["ID"]]
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
	id_to_slot.erase(g["ID"])
	slot_to_id.erase(last_slot)
	
	instance_number -= 1
	multimesh.visible_instance_count = instance_number
	if shadow:
		shadow.multimesh.visible_instance_count = instance_number

	
	
