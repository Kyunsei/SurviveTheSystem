extends MultiMeshInstance3D


var id_to_slot := {}
var slot_to_id := {}
var instance_number := 0

func init():
	id_to_slot = {}
	slot_to_id = {}
	instance_number = 0

func _ready() -> void:
	multimesh.instance_count = 100000

func update_drawn_grass(index,position):
	#var ID = gen[0]
	#return
	#var current_energy = g["current_energy"]
	#if id_to_slot.size() > g["ID"]:
	if !id_to_slot.has(index):
		print("strange")
		return
	var slot = id_to_slot[index]
	#var current_transform = multimesh.get_instance_transform(slot)
	var newscale = Vector3(1,1,1)
		#newtransform.origin =  g["position"] #Vector3(slot * 2.0, 0, 0)
	#current_transform.basis = Basis().scaled(Vector3.ONE * newscale)
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * newscale),  position))
	'if g["Alive"]==0:
		#print(color_from_biomass(g["Biomass"],200))
		multimesh.set_instance_color(slot, color_from_biomass(g["Biomass"],500))
	else:'
	multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))



func draw_new_grass(index,position):
	var slot = instance_number
	
	id_to_slot[index] = slot
	slot_to_id[slot] = index	
	var newscale = Vector3(1,1,1) #clamp( float(g["current_life_state"])/5,0.2,1)
	var pos = position
	#current_transform.basis = Basis().scaled(Vector3.ONE * newscale)
	'if g["current_life_state"] == 0:
		pos.y = -100'
		
	multimesh.set_instance_transform(slot, Transform3D(Basis().scaled(Vector3.ONE * newscale), pos))
	'if g["Alive"]==0:
		multimesh.set_instance_color(slot, color_from_biomass(g["Biomass"],500))
	else:'
	multimesh.set_instance_color(slot, Color(1.0, 1.0, 1.0, 1.0))
	instance_number += 1
	multimesh.visible_instance_count = instance_number 

	
func remove_grass(index):
	#return
	if !id_to_slot.has(index):	
		return

	var slot = id_to_slot[index]
	var last_slot = instance_number - 1
	
	if slot != last_slot:
		# Move last transform into removed slot
		multimesh.set_instance_transform(
			slot,
			multimesh.get_instance_transform(last_slot)
		)

		# Update mappings
		var moved_id = slot_to_id[last_slot]
		id_to_slot[moved_id] = slot
		slot_to_id[slot] = moved_id	
	# Remove mappings
	id_to_slot.erase(index)
	slot_to_id.erase(last_slot)
	
	instance_number -= 1
	multimesh.visible_instance_count = instance_number
	
