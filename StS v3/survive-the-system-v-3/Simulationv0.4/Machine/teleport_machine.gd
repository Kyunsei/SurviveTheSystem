extends Machine

@export var tp_pos: Vector3
@export var new_ground: float 

func _process(delta: float) -> void:
	_follow_view()                        # out of energy
	_update_label()

## Turn a carried agent into energy. Refused when the machine is full.
func feed(sp, j: int) -> bool:
	return false


func interact(agent_species, agent_index: int, held_species, held_index: int) -> bool:
	agent_species.position_array[agent_index] = tp_pos
	agent_species.ground_y = new_ground
	return true
	
	
func _update_label() -> void:
	var ratio :=1 # energy / max_energy if max_energy > 0.0 else 0.0
	_label.text = "%s\n" % [machine_name]
	_label.modulate = Color.RED.lerp(Color.GREEN, ratio)
