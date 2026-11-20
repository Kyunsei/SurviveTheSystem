extends Node

## Agent hover / follow / kill / control for the 3D view (works with FlyCamera).
##
## Hover:        the mouse is always visible: hovering an agent outlines it
## F:            follow the hovered agent | while following: stop following
## K:            kill the hovered agent
## C:            take control of the hovered (or followed) agent | C again: release it
##   In control: WASD moves the agent (world directions, not the camera's)
##               the closest other agent is outlined, SPACE interacts with it
##               a small energy bar is shown above the controlled agent
##               an arrow on the ground shows where it is facing
##               1: north view (default): camera faces north, W = north, right drag only tilts
##               2: camera view: right drag turns freely, W = where the camera looks
## P:            pause / resume the simulation
## F1 or "?" button (top right): show / hide the controls help
## O:            open / close the menu. Independent from picking.
##
## Control needs two variables in the species script, read by the simulation:
##   var player_index := -1                 # local index of the controlled agent (-1 = none)
##   var player_velocity := Vector3.ZERO    # velocity chosen by the player

signal agent_hovered(species, index: int)      # species = null when nothing is hovered
signal agent_followed(species, index: int)
signal agent_killed(species, index: int)
signal control_started(species, index: int)
signal control_ended(species, index: int)
#signal agent_interacted(species, index: int, target_species, target_index: int)

@export var alifemanager: AlifeManager
@export var camera: FlyCamera
@export var menu: CanvasLayer                  # opened / closed with O
@export var sim_manager: SimulationManager

@export_group("Picking")
@export var pick_margin_px := 4.0              # extra pixels around each sprite
@export var max_sprite_height := 3.0           # world units: tallest sprite (with its size)
@export var max_search_cells := 6              # cap on the grid area searched along the ray
@export var show_tooltip := true

@export_group("Control")
@export var control_speed := 3.0               # world units per second
@export var target_range := 3.0                # max distance for the outlined / interact target
@export var target_search_rings := 2           # grid rings searched for the closest agent
@export var energy_bar_max := 10.0             # energy shown as a full bar
@export var energy_bar_size := Vector2(36, 5)  # pixels
@export var arrow_color := Color(1.0, 1.0, 1.0, 0.75)
@export var arrow_scale := 1.0                 # relative to the agent's width

enum ControlView { NORTH, CAMERA }
## 1 = NORTH: camera locked facing north, W always goes north
## 2 = CAMERA: camera turns freely, W goes where the camera looks
@export var control_view := ControlView.NORTH

var old_speed := 0.0

var hovered_species = null
var hovered_index := -1
var followed_species = null
var followed_index := -1
var controlled_species = null
var controlled_index := -1
var target_species = null
var target_index := -1

var _outlined_species = null
var _outlined_index := -1

var _layer := CanvasLayer.new()
var _tooltip := PanelContainer.new()
var _tooltip_label := Label.new()
var _bar_bg := ColorRect.new()
var _bar_fill := ColorRect.new()
var _arrow := MeshInstance3D.new()
var _facing := Vector3.FORWARD
var _status := Label.new()
var _help_button := Button.new()
var _help_panel := PanelContainer.new()


func _ready() -> void:
	_layer.layer = 90
	add_child(_layer)
	_build_tooltip()
	_build_energy_bar()
	_build_arrow()
	_build_status()
	_build_help()
	camera.follow_stopped.connect(_on_follow_stopped)
	if menu != null:
		menu.visible = false


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return

	match event.physical_keycode:
		KEY_O:
			_toggle_menu()
			get_viewport().set_input_as_handled()

		KEY_C:
			if controlled_species != null:
				_release_control()
			elif hovered_species != null:
				_take_control(hovered_species, hovered_index)
			elif followed_species != null:
				_take_control(followed_species, followed_index)
			get_viewport().set_input_as_handled()

		KEY_1, KEY_KP_1:
			if controlled_species != null:
				_set_control_view(ControlView.NORTH)
				get_viewport().set_input_as_handled()

		KEY_2, KEY_KP_2:
			if controlled_species != null:
				_set_control_view(ControlView.CAMERA)
				get_viewport().set_input_as_handled()

		KEY_F1:
			_help_button.button_pressed = not _help_button.button_pressed
			get_viewport().set_input_as_handled()

		KEY_SPACE:
			if controlled_species != null:
				if target_species != null:
					_interact(controlled_species, controlled_index, target_species, target_index)
				get_viewport().set_input_as_handled()

		KEY_F:
			if controlled_species != null:
				return                                     # the camera already follows it
			if camera.is_following():
				camera.stop_follow()
			elif hovered_species != null:
				_follow(hovered_species, hovered_index)
			get_viewport().set_input_as_handled()

		KEY_K:
			if hovered_species != null:
				_kill(hovered_species, hovered_index)
				get_viewport().set_input_as_handled()

		KEY_P:
			if sim_manager.simulation_speed == 0:
				sim_manager.simulation_speed = old_speed
			else:
				old_speed = sim_manager.simulation_speed
				sim_manager.simulation_speed = 0
			get_viewport().set_input_as_handled()



func _toggle_menu() -> void:
	if menu == null:
		return
	menu.visible = not menu.visible
	var mode_2 := controlled_species != null and control_view == ControlView.CAMERA
	camera.set_mouse_look(mode_2 and not menu.visible)

# --- Per frame -----------------------------------------------------------------

func _process(_delta: float) -> void:
	# Hover (not while right-dragging the view)
	var sp = null
	var i := -1
	if not camera.is_dragging() and not camera.is_mouse_look():
		var hit := _pick_at(get_viewport().get_mouse_position())
		if not hit.is_empty():
			sp = hit[0]
			i = hit[1]
	if sp != hovered_species or i != hovered_index:
		hovered_species = sp
		hovered_index = i
		agent_hovered.emit(sp, i)

	if controlled_species != null:
		_process_control()


	# Outline priority: interact target > hovered > followed
	if target_species != null:
		_set_outline(target_species, target_index)
	elif hovered_species != null:
		_set_outline(hovered_species, hovered_index)
	elif followed_species != null and controlled_species == null:
		_set_outline(followed_species, followed_index)
	else:
		_set_outline(null, -1)

	_update_tooltip()
	_update_energy_bar()
	_update_arrow()
	_update_status()


# --- Control -------------------------------------------------------------------

func _take_control(sp, i: int) -> void:
	if not ("player_index" in sp):
		push_error("Species script needs `player_index` and `player_velocity` for control mode")
		return
	_release_control()
	controlled_species = sp
	controlled_index = i
	sp.player_index = i
	sp.player_velocity = Vector3.ZERO

	# Start the arrow in the direction the agent was already moving
	var v: Vector3 = sp.current_velocity[i]
	v.y = 0.0
	_facing = v.normalized() if v.length_squared() > 1e-6 else Vector3.FORWARD

	camera.move_keys_enabled = false                   # WASD moves the agent, not the camera
	_follow(sp, i)
	_set_control_view(control_view)
	control_started.emit(sp, i)


func _set_control_view(view: ControlView) -> void:
	control_view = view
	camera.set_yaw_lock(view == ControlView.NORTH, 0.0)
	camera.set_mouse_look(view == ControlView.CAMERA)

func _release_control() -> void:
	if controlled_species == null:
		return
	var sp = controlled_species
	var i := controlled_index
	sp.player_index = -1
	sp.player_velocity = Vector3.ZERO
	controlled_species = null
	controlled_index = -1
	target_species = null
	target_index = -1
	camera.move_keys_enabled = true
	camera.set_yaw_lock(false)
	control_ended.emit(sp, i)
	camera.set_mouse_look(false)


var sprint := 1.0
func _process_control() -> void:
	var sp = controlled_species
	var i := controlled_index
	if sp.active_alife_array[i] == 0 or sp.alive_array[i] == 0:
		_release_control()                             # the agent died
		return

	# WASD: x = right, y = forward
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): input.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): input.x += 1.0
	sprint = 2.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0

	var dir := Vector3.ZERO
	if control_view == ControlView.NORTH:
		dir = Vector3(input.x, 0.0, -input.y)          # W = north (-Z), D = east (+X)
	else:
		# Relative to where the camera looks, flattened on the ground
		var b := camera.global_transform.basis
		var fwd := Vector3(-b.z.x, 0.0, -b.z.z).normalized()
		var right := Vector3(b.x.x, 0.0, b.x.z).normalized()
		dir = right * input.x + fwd * input.y
	sp.player_velocity = dir.normalized() * control_speed*sprint

	# Closest other agent (any species) within range
	target_species = null
	target_index = -1
	var me: int = alifemanager.global_species_offset[alifemanager.species_array.find(sp)] + i
	var found: Vector4 = sp.find_nearest(sp.position_array[i], me, -1, target_search_rings)
	var id := int(found.w)
	if id >= 0 and Vector3(found.x, found.y, found.z).length() <= target_range:
		var t := _split_id(id)
		target_species = t[0]
		target_index = t[1]


## SPACE in control mode. Replace the body with your interaction (eat, mate, attack...).
func _interact(sp, i: int, target_sp, j: int) -> void:
	print("%s #%d interacts with %s #%d" % [sp.species_name, i, target_sp.species_name, j])
	#agent_interacted.emit(sp, i, target_sp, j)
	target_sp.Interact(j,sp,i)

# --- Follow / kill / outline -----------------------------------------------------

func _follow(sp, i: int) -> void:
	followed_species = sp
	followed_index = i
	camera.follow(func():
		if sp.active_alife_array[i] == 0 or sp.alive_array[i] == 0:
			return null                                # gone: the camera goes back to fly mode
		return sp.position_array[i])
	agent_followed.emit(sp, i)


func _on_follow_stopped() -> void:
	followed_species = null
	followed_index = -1


func _kill(sp, i: int) -> void:
	# Through energy, so the simulation handles death and removal as usual
	sp.current_energy_array[i] = -1.0
	agent_killed.emit(sp, i)


func _set_outline(sp, i: int) -> void:
	if sp == _outlined_species and i == _outlined_index:
		return
	if _outlined_species != null:
		_outlined_species.renderer3D.material_override.set_shader_parameter("selected_id", -1)
	_outlined_species = sp
	_outlined_index = i
	if sp != null:
		sp.renderer3D.material_override.set_shader_parameter("selected_id", i)


func _split_id(id: int) -> Array:
	var offs: PackedInt32Array = alifemanager.global_species_offset
	var s := offs.bsearch(id, false) - 1
	return [alifemanager.species_array[s], id - offs[s]]


# --- Picking -------------------------------------------------------------------

## Returns [species, local_index] of the front-most agent under screen_pos, or [].
func _pick_at(screen_pos: Vector2) -> Array:
	var am := alifemanager
	var cam := get_viewport().get_camera_3d()
	if cam == null or am == null or am.global_entity_count == 0:
		return []

	# 1. The part of the cursor ray where sprites can be: between the ground and max height
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	var low = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	var high = Plane(Vector3.UP, max_sprite_height).intersects_ray(from, dir)
	if low == null and high == null:
		return []
	if low == null: low = high
	if high == null: high = low

	# 2. Grid cells covering that segment (+ one sprite of margin), capped
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var mid: Vector3 = (low + high) * 0.5
	var half: Vector3 = (high - low).abs() * 0.5 + Vector3.ONE * max_sprite_height
	var cx := clampi(int(mid.x / cs.x), 0, W - 1)
	var cz := clampi(int(mid.z / cs.z), 0, D - 1)
	var nx := mini(ceili(half.x / cs.x), max_search_cells)
	var nz := mini(ceili(half.z / cs.z), max_search_cells)

	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var active: PackedInt32Array = am.global_active
	var offs: PackedInt32Array = am.global_species_offset

	var quads: Array[Vector2] = []
	for sp in am.species_array:
		quads.append((sp.renderer3D.multimesh.mesh as QuadMesh).size)

	# 3. Test each candidate's sprite on screen; keep the one closest to the camera
	var best := -1
	var best_depth := INF
	var cam_pos := cam.global_position
	for z in range(maxi(cz - nz, 0), mini(cz + nz, D - 1) + 1):
		for y in H:
			for x in range(maxi(cx - nx, 0), mini(cx + nx, W - 1) + 1):
				var cell := x + W * (y + H * z)
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j: int = cell_items[k]
					if active[j] == 0:
						continue
					var s := offs.bsearch(j, false) - 1
					var q: Vector2 = quads[s]
					var size: float = am.species_array[s].current_size[j - offs[s]]

					var foot: Vector3 = sorted_pos[k]
					var top := foot + Vector3(0.0, q.y * size, 0.0)
					if cam.is_position_behind(foot) and cam.is_position_behind(top):
						continue
					var a := cam.unproject_position(foot)
					var b := cam.unproject_position(top)
					var half_w := 0.5 * (q.x / q.y) * a.distance_to(b) + pick_margin_px
					if _dist_to_segment(screen_pos, a, b) > half_w:
						continue

					var depth := cam_pos.distance_squared_to(foot)
					if depth < best_depth:
						best_depth = depth
						best = j

	if best < 0:
		return []
	return _split_id(best)


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1e-6:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Facing arrow (on the ground, in control mode) -------------------------------

func _build_arrow() -> void:
	# Flat chevron in the XZ plane, pointing toward +Z, starting a bit ahead of the agent
	var verts := PackedVector3Array([
		Vector3(0.0, 0.0, 1.0), Vector3(-0.35, 0.0, 0.4), Vector3(0.0, 0.0, 0.55),
		Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, 0.55), Vector3(0.35, 0.0, 0.4),
	])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = arrow_color
	mesh.surface_set_material(0, mat)

	_arrow.mesh = mesh
	_arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow.visible = false
	add_child(_arrow)


func _update_arrow() -> void:
	var sp = controlled_species
	if sp == null:
		_arrow.visible = false
		return
	var i := controlled_index

	# Facing: the keys being pressed (instant, even when paused), else the real movement
	var v: Vector3 = sp.player_velocity
	if v.length_squared() < 1e-6:
		v = sp.current_velocity[i]
	v.y = 0.0
	if v.length_squared() > 1e-6:
		_facing = v.normalized()                       # standing still: keep the last direction

	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var s := maxf(q.x * sp.current_size[i], 0.3) * arrow_scale
	var angle := atan2(_facing.x, _facing.z)
	var basis := Basis(Vector3.UP, angle).scaled(Vector3.ONE * s)
	var p: Vector3 = sp.position_array[i]
	_arrow.global_transform = Transform3D(basis, p + Vector3(0.0, 0.03, 0.0))
	_arrow.visible = true


# --- Energy bar ------------------------------------------------------------------

func _build_energy_bar() -> void:
	_bar_bg.color = Color(0, 0, 0, 0.6)
	_bar_bg.size = energy_bar_size + Vector2(2, 2)
	_bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.visible = false
	_bar_fill.position = Vector2(1, 1)
	_bar_fill.size = energy_bar_size
	_bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bg.add_child(_bar_fill)
	_layer.add_child(_bar_bg)


func _update_energy_bar() -> void:
	var sp = controlled_species
	var cam := get_viewport().get_camera_3d()
	if sp == null or cam == null:
		_bar_bg.visible = false
		return

	var i := controlled_index
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var size: float = sp.current_size[i]
	var above: Vector3 = sp.position_array[i] + Vector3(0.0, q.y * size + 0.2, 0.0)
	if cam.is_position_behind(above):
		_bar_bg.visible = false
		return

	var ratio := clampf(sp.current_energy_array[i] / sp.max_energy, 0.0, 1.0)
	_bar_fill.size.x = energy_bar_size.x * ratio
	_bar_fill.color = Color.RED.lerp(Color.GREEN, ratio)
	_bar_bg.position = cam.unproject_position(above) - Vector2(_bar_bg.size.x * 0.5, _bar_bg.size.y)
	_bar_bg.visible = true


# --- Status line (top center, in control mode) -----------------------------------

func _build_status() -> void:
	_status.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE, 12)
	_status.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.add_theme_font_size_override("font_size", 13)
	_status.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_status.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	_status.add_theme_constant_override("shadow_offset_x", 1)
	_status.add_theme_constant_override("shadow_offset_y", 1)
	_status.visible = false
	_layer.add_child(_status)


func _update_status() -> void:
	if controlled_species == null:
		_status.visible = false
		return
	var view := "[1] North view" if control_view == ControlView.NORTH else "[2] Camera view"
	_status.text = "Controlling %s #%d   ·   %s   ·   C  release" % [
			controlled_species.species_name, controlled_index, view]
	_status.visible = true


# --- Help ("?" button, top right) -------------------------------------------------

const HELP := [
	["CAMERA", ""],
	["WASD", "move over the ground"],
	["E / Q", "up / down"],
	["Shift", "faster"],
	["Wheel", "zoom (distance when following)"],
	["Right drag", "rotate the view"],
	["", ""],
	["AGENTS", ""],
	["Hover", "outline + info"],
	["F", "follow / stop following"],
	["K", "kill"],
	["C", "take control / release"],
	["", ""],
	["CONTROL", ""],
	["WASD", "move the agent"],
	["Space", "interact with the outlined agent"],
	["1", "north view: W = north"],
	["2", "camera view: W = forward"],
	["C", "release the agent"],
	["", ""],
	["OTHER", ""],
	["P", "pause / resume"],
	["O", "menu"],
	["H", "camera overlay"],
	["F1", "this help"],
]


func _build_help() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_layer.add_child(box)

	_help_button.text = "?"
	_help_button.tooltip_text = "Controls (F1)"
	_help_button.toggle_mode = true
	_help_button.focus_mode = Control.FOCUS_NONE       # never steals Space / Enter
	_help_button.custom_minimum_size = Vector2(28, 28)
	_help_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_help_button.toggled.connect(func(on: bool): _help_panel.visible = on)
	box.add_child(_help_button)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.75)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	_help_panel.add_theme_stylebox_override("panel", style)
	_help_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_help_panel.visible = false
	box.add_child(_help_panel)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 2)
	_help_panel.add_child(grid)

	for row in HELP:
		var key := Label.new()
		var action := Label.new()
		key.text = row[0]
		action.text = row[1]
		var is_title: bool = row[1] == "" and row[0] != ""
		key.add_theme_font_size_override("font_size", 12)
		action.add_theme_font_size_override("font_size", 12)
		key.add_theme_color_override("font_color",
				Color(1.0, 0.85, 0.4) if is_title else Color(1, 1, 1, 0.95))
		action.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
		grid.add_child(key)
		grid.add_child(action)


# --- Hover tooltip -------------------------------------------------------------

func _build_tooltip() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_tooltip.add_theme_stylebox_override("panel", style)
	_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.visible = false

	_tooltip_label.add_theme_font_size_override("font_size", 12)
	_tooltip_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip.add_child(_tooltip_label)
	_layer.add_child(_tooltip)


func _update_tooltip() -> void:
	if not show_tooltip or hovered_species == null:
		_tooltip.visible = false
		return

	_tooltip_label.text = _agent_text(hovered_species, hovered_index)
	_tooltip.reset_size()
	_tooltip.visible = true

	var screen := get_viewport().get_visible_rect().size
	var tip := _tooltip.get_combined_minimum_size()
	var pos := get_viewport().get_mouse_position() + Vector2(16, 16)
	pos.x = minf(pos.x, screen.x - tip.x - 4.0)
	pos.y = minf(pos.y, screen.y - tip.y - 4.0)
	_tooltip.position = pos


## What the tooltip shows. Adapt the field names to your species script.
func _agent_text(sp, i: int) -> String:
	var lines := PackedStringArray()
	lines.append("%s  #%d" % [sp.species_name, i])
	lines.append("Energy  %.2f" % sp.current_energy_array[i])
	lines.append("Biomass  %.2f" % sp.current_biomass[i])
	lines.append("LifeCycle  %d" % sp.current_life_state[i])
	if sp.alive_array[i] == 0:
		lines.append("(dead)")
	lines.append("F follow   C control   K kill")
	return "\n".join(lines)
