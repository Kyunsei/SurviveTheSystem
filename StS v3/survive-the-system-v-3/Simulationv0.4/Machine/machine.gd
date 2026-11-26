class_name Machine
extends Node3D
## Base machine: stores energy, consumes it while running, refuelled by the player.
##
## In control mode, near a machine (it gets a ring on the ground):
##   Left click / R while carrying an agent: feed it to the machine (biomass -> energy)
##   Left click / R with empty hands:        start / stop the machine
##
## Make a scene per machine type: a Node3D with this script (or a script that extends
## Machine), and its mesh as a child. Put what it produces in _work().
## Machines find each other through the "machines" group: no manager needed.

signal energy_changed(energy: float, max_energy: float)
signal started
signal stopped
signal fed(species, index: int, energy_gained: float)

@export var machine_name := "Machine"
@export var energy := 0.0
@export var max_energy := 100.0
@export var consumption := 2.0               # energy per second while running
@export var energy_per_biomass := 1.0        # energy gained per unit of biomass fed to it
@export var start_running := false
## How close (from the machine's center) the player must be to use it.
## Set it per machine: bigger machines need a bigger range. The ring shows this zone.
@export var interact_range := 2.0
@export var label_height := 2.0              # where the status text floats

var running := false

var _ring := MeshInstance3D.new()
var _label := Label3D.new()
var _base_pos := {}                          # child -> its position in the scene


func _ready() -> void:
	add_to_group("machines")
	_build_ring()
	_build_label()
	running = start_running and energy > 0.0
	_update_label()
	# Remember where the visuals sit, so they can follow the planet curve / wrap view
	for c in get_children():
		if c is Node3D:
			_base_pos[c] = c.position


# --- Called by the player controller ------------------------------------------------

## Left click / R near the machine. Returns true if the carried item was used.
func interact(agent_species, agent_index: int, held_species, held_index: int) -> bool:
	if held_species != null and held_species.has_method("empty_tank"):
		var biomass: float = held_species.empty_tank(held_index)
		print("Machine got %.1f biomass from the vacuum" % biomass)
		var gained := minf(biomass * energy_per_biomass, max_energy - energy)
		energy += gained
		_update_label()

		# ... use it: fuel, credits, progress ...
		return false                     # the vacuum stays in your hands, empty
	# ... your existing behaviour for other items ...
	if held_species != null:
		return feed(held_species, held_index)
	if running:
		stop()
	else:
		start()
	return false


## Turn a carried agent into energy. Refused when the machine is full.
func feed(sp, j: int) -> bool:
	if energy >= max_energy:
		return false
	var gained := minf(sp.current_biomass[j] * energy_per_biomass, max_energy - energy)
	energy += gained
	sp.Remove_Life(j)                         # the item is consumed
	fed.emit(sp, j, gained)
	energy_changed.emit(energy, max_energy)
	_update_label()
	return true


func start() -> void:
	if running or energy <= 0.0:
		return
	running = true
	started.emit()
	_update_label()


func stop() -> void:
	if not running:
		return
	running = false
	stopped.emit()
	_update_label()


func set_highlight(on: bool) -> void:
	_ring.visible = on


## Text shown in the controller's status line when the player stands next to it.
func status_text() -> String:
	return "%s   ·   Energy %d / %d   ·   %s" % [
			machine_name, roundi(energy), roundi(max_energy), "ON" if running else "OFF"]


# --- Running -----------------------------------------------------------------------

func _process(delta: float) -> void:
	_follow_view()
	if not running:
		return
	var used := minf(consumption * delta, energy)
	energy -= used
	_work(delta)
	energy_changed.emit(energy, max_energy)
	if energy <= 0.0:
		energy = 0.0
		stop()                                # out of energy
	_update_label()


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

func _build_ring() -> void:
	# The ring marks the interaction zone on the ground
	var torus := TorusMesh.new()
	torus.inner_radius = interact_range * 0.95
	torus.outer_radius = interact_range
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	torus.material = mat
	_ring.mesh = torus
	_ring.scale = Vector3(1.0, 0.05, 1.0)    # flat on the ground
	_ring.position.y = 0.03
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func _build_label() -> void:
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = label_height
	_label.font_size = 48
	_label.pixel_size = 0.005
	_label.outline_size = 8
	_label.no_depth_test = true                # readable through grass
	add_child(_label)


func _update_label() -> void:
	var ratio := energy / max_energy if max_energy > 0.0 else 0.0
	_label.text = "%s\n%d / %d  %s" % [machine_name, roundi(energy), roundi(max_energy),
			"ON" if running else "OFF"]
	_label.modulate = Color.RED.lerp(Color.GREEN, ratio)
