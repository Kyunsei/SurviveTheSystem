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
			  # where the status text floats

					   # child -> its position in the scene


func _ready() -> void:
	add_to_group("machines")
	for c in get_children():
		if c is Node3D:
			_base_pos[c] = c.position


# --- Called by the player controller ------------------------------------------------

## Left click / R near the machine. Returns true if the carried item was used.
func interact(agent_species, agent_index: int, held_species, held_index: int) -> bool:

	return false


## Turn a carried agent into energy. Refused when the machine is full.
func feed(sp, j: int) -> bool:

	return true


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


## Override in a script that extends Machine: what the machine does while running.
## Called every frame while it has energy.
func _work(_delta: float) -> void:
	pass


# --- Visuals -----------------------------------------------------------------------

## Move the visible children (not the node itself, whose position is the machine's
## real place for the game logic) to where the machine is DRAWN: the copy near the view
## (wrap view) bent onto the little planet. Does nothing in a flat, non-wrapped view.
func _follow_view() -> void:
	var cam := get_viewport().get_camera_3d()
	var center: Vector3 = (cam as FlyCamera).get_wrap_center() if cam is FlyCamera \
			else (cam.global_position if cam else global_position)
	var drawn := WorldWrap.curve(WorldWrap.nearest_image(global_position, center), center)
	var offset := global_transform.basis.inverse() * (drawn - global_position)
	for c in _base_pos:
		if is_instance_valid(c):
			c.position = _base_pos[c] + offset






func _update_label() -> void:
	pass
