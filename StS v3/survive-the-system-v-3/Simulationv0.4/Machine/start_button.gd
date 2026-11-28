extends Machine
## Base machine: stores energy, consumes it while running, refuelled by the player.
##
## In control mode, near a machine (it gets a ring on the ground):
##   Left click / R while carrying an agent: feed it to the machine (biomass -> energy)
##   Left click / R with empty hands:        start / stop the machine
##
## Make a scene per machine type: a Node3D with this script (or a script that extends
## Machine), and its mesh as a child. Put what it produces in _work().
## Machines find each other through the "machines" group: no manager needed.
					# child -> its position in the scene

@export var next_scene : PackedScene

func _ready() -> void:
	add_to_group("machines")
	_build_ring()
	for c in get_children():
		if c is Node3D:
			_base_pos[c] = c.position


# --- Called by the player controller ------------------------------------------------

func interact(agent_species, agent_index: int, held_species, held_index: int) -> bool:
	if next_scene != null:
		var net := get_node_or_null("/root/Network")
		if net != null:
			net.change_scene(next_scene.resource_path)
		else:
			get_tree().change_scene_to_packed.call_deferred(next_scene)
	return false

## Turn a carried agent into energy. Refused when the machine is full.
func feed(sp, j: int) -> bool:
	return false


func start() -> void:
	pass


func stop() -> void:
	pass	


func set_highlight(on: bool) -> void:
	_ring.visible = on


## Text shown in the controller's status line when the player stands next to it.
func status_text() -> String:
	return "%s   ·   Energy %d / %d   ·   %s" % [
			machine_name, roundi(energy), roundi(max_energy), "ON" if running else "OFF"]


# --- Running -----------------------------------------------------------------------

func _process(delta: float) -> void:
	if follow_view:
		_follow_view()
	pass
