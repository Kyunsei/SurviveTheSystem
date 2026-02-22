extends MultiMeshInstance3D


var id_to_slot := {}
var slot_to_id := {}
var instance_number := 0
var shadow

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

func draw_new_grass(g):
	
	var slot = instance_number
	
	id_to_slot[g["ID"]] = slot
	slot_to_id[slot] = g["ID"]	
	
	var newtransform = Transform3D.IDENTITY

	#var random_scale = randf_range(1, 5.0)
	var scale = clamp(g["current_energy"]/10,0.5,1)
	newtransform.origin =  g["position"] #Vector3(slot * 2.0, 0, 0)
	#newtransform.basis = Basis().scaled(Vector3(2, 2, 2))
	newtransform.basis = Basis().scaled(Vector3.ONE * scale)

	#multimesh.set_instance_transform(slot, Transform3D(Basis(), g["position"]))
	multimesh.set_instance_transform(slot, newtransform)


	instance_number += 1
	multimesh.visible_instance_count = instance_number 
	
	if shadow:
		shadow.multimesh.set_instance_transform(slot, Transform3D(Basis(), g["position"]))
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

	
	
