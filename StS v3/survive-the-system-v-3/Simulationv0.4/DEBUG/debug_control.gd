class_name AgentPicker
extends Node
## Observing the world (works with PlayerController and FlyCamera).
##
## Hover:        the mouse is always visible: hovering an agent outlines it + tooltip
## agent_follow  (F):  follow the hovered agent | while following: stop following
## agent_kill    (K):  kill the hovered agent
## sim_pause     (P):  pause / resume the simulation
## menu_toggle   (O):  open / close the menu
## controls_open (F1) or "Controls" button (top right): open the key remap menu
##
## The keys are Input Map actions, so they can be changed in the remap menu
## (add them to Settings.REMAPPABLE).
##
## Also owns the outline (one per species material), so it decides what is outlined:
##   controller's target > carried agent > hovered agent > followed agent
## Controlling an agent (C, WASD, carrying...) is in PlayerController.

signal agent_hovered(species, index: int)      # species = null when nothing is hovered
signal agent_followed(species, index: int)
signal agent_killed(species, index: int)

@export var alifemanager: AlifeManager
@export var camera: FlyCamera
@export var controller: PlayerController
@export var menu: CanvasLayer                  # opened / closed with menu_toggle
@export var sim_manager: SimulationManager

@export_group("Picking")
@export var pick_margin_px := 4.0              # extra pixels around each sprite
@export var max_sprite_height := 3.0           # world units: tallest sprite (with its size)
@export var max_search_cells := 6              # cap on the grid area searched along the ray
@export var show_tooltip := true

var hovered_species = null
var hovered_index := -1
var followed_species = null
var followed_index := -1
var old_speed := 0.0

var _outlined_species = null
var _outlined_index := -1

var _layer := CanvasLayer.new()
var _tooltip := PanelContainer.new()
var _tooltip_label := Label.new()
var _controls_button := Button.new()
var _controls_menu: SettingsRemapMenu

func _ready() -> void:
	_layer.layer = 90
	add_child(_layer)
	_build_tooltip()
	_build_controls_button()
	camera.follow_stopped.connect(_on_follow_stopped)
	if menu != null:
		menu.visible = false


# --- Public ----------------------------------------------------------------------

## Follow an agent with the camera (also used by the controller).
func follow(sp, i: int) -> void:
	followed_species = sp
	followed_index = i
	camera.follow(func():
		if sp.active_alife_array[i] == 0 or sp.alive_array[i] == 0:
			return null                                # gone: the camera goes back to fly mode
		return sp.position_array[i])
	agent_followed.emit(sp, i)


## Global id (grid / find_nearest) -> [species, local_index]
func split_id(id: int) -> Array:
	var offs: PackedInt32Array = alifemanager.global_species_offset
	var s := offs.bsearch(id, false) - 1
	return [alifemanager.species_array[s], id - offs[s]]


# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("menu_toggle"):
		_toggle_menu()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("controls_open"):
		_toggle_controls()
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("agent_follow"):
		if controller.is_controlling():
			return                                     # the camera already follows it
		if camera.is_following():
			camera.stop_follow()
		elif hovered_species != null:
			follow(hovered_species, hovered_index)
		get_viewport().set_input_as_handled()

	elif event.is_action_pressed("agent_kill"):
		if hovered_species != null:
			_kill(hovered_species, hovered_index)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("agent_remove"):
		if hovered_species != null:
			_remove(hovered_species, hovered_index)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sim_pause"):
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
	_update_mouse_look()


func _update_mouse_look() -> void:
	var menu_open := menu != null and menu.visible
	camera.set_mouse_look(controller.wants_mouse_look() and not menu_open)


# --- Per frame -----------------------------------------------------------------

func _process(_delta: float) -> void:
	# Hover (not while the mouse turns the view)
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

	# Outline priority: controller's target > carried > hovered > followed
	if controller.target_species != null:
		_set_outline(controller.target_species, controller.target_index)
	elif controller.held_species != null:
		_set_outline(controller.held_species, controller.held_index)
	elif hovered_species != null:
		_set_outline(hovered_species, hovered_index)
	elif followed_species != null and not controller.is_controlling():
		_set_outline(followed_species, followed_index)
	else:
		_set_outline(null, -1)

	_update_tooltip()


# --- Follow / kill / outline -----------------------------------------------------

func _on_follow_stopped() -> void:
	followed_species = null
	followed_index = -1


func _kill(sp, i: int) -> void:
	# Through energy, so the simulation handles death and removal as usual
	sp.current_energy_array[i] = -1.0
	agent_killed.emit(sp, i)
	
func _remove(sp, i: int) -> void:
	# Through energy, so the simulation handles death and removal as usual
	sp.Remove_Life(i)


func _set_outline(sp, i: int) -> void:
	if sp == _outlined_species and i == _outlined_index:
		return
	if _outlined_species != null:
		_outlined_species.renderer3D.material_override.set_shader_parameter("selected_id", -1)
	_outlined_species = sp
	_outlined_index = i
	if sp != null:
		sp.renderer3D.material_override.set_shader_parameter("selected_id", i)


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

	# 2. Grid cells covering that segment (+ one sprite of margin), capped.
	#    With the wrap view on, the search continues through the borders.
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var mid: Vector3 = (low + high) * 0.5
	var half: Vector3 = (high - low).abs() * 0.5 + Vector3.ONE * max_sprite_height
	var vm := WorldWrap.view_mask()
	var wrap_x := vm.x > 0.0
	var wrap_z := vm.z > 0.0
	var mid_w := WorldWrap.wrap_into(mid) if WorldWrap.visual else mid
	var cx := clampi(int(mid_w.x / cs.x), 0, W - 1)
	var cz := clampi(int(mid_w.z / cs.z), 0, D - 1)
	var nx := mini(ceili(half.x / cs.x), max_search_cells)
	var nz := mini(ceili(half.z / cs.z), max_search_cells)
	if wrap_x: nx = mini(nx, (W - 1) / 2)             # don't visit a column twice
	if wrap_z: nz = mini(nz, (D - 1) / 2)

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
	var center := camera.get_wrap_center()
	for zz in range(cz - nz, cz + nz + 1):
		var z := posmod(zz, D) if wrap_z else zz
		if z < 0 or z >= D:
			continue
		for y in H:
			for xx in range(cx - nx, cx + nx + 1):
				var x := posmod(xx, W) if wrap_x else xx
				if x < 0 or x >= W:
					continue
				var cell := x + W * (y + H * z)
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j: int = cell_items[k]
					if active[j] == 0:
						continue
					var s := offs.bsearch(j, false) - 1
					var q: Vector2 = quads[s]
					var size: float = am.species_array[s].current_size[j - offs[s]]

					# The copy of the agent that is actually drawn
					var foot: Vector3 = WorldWrap.curve(
							WorldWrap.nearest_image(sorted_pos[k], center), center)
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
	return split_id(best)


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1e-6:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Controls (button top right -> key remap menu) ---------------------------------

func _build_controls_button() -> void:
	_controls_button.text = "Controls"
	_controls_button.tooltip_text = "Controls (F1)"
	_controls_button.focus_mode = Control.FOCUS_NONE   # never steals Space / Enter
	_controls_button.custom_minimum_size = Vector2(28, 28)
	_controls_button.pressed.connect(_toggle_controls)
	_layer.add_child(_controls_button)
	_controls_button.set_anchors_and_offsets_preset(
			Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	_controls_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN


func _toggle_controls() -> void:
	# Already open: close it
	if is_instance_valid(_controls_menu):
		_controls_menu._on_back()
		return

	_tooltip.visible = false                           # _process stops while paused
	camera.set_mouse_look(false)                       # free the cursor to click the menu

	_controls_menu = SettingsRemapMenu.open(self)
	# Draw above this node's own layer (90), so the button and tooltip stay underneath
	(_controls_menu.get_parent() as CanvasLayer).layer = _layer.layer + 10

	# Freeze the game so the keys pressed while rebinding don't move anything
	var was_paused := get_tree().paused
	get_tree().paused = true
	_controls_menu.closed.connect(func():
		get_tree().paused = was_paused
		_update_mouse_look())


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
	lines.append("%s follow   %s control   %s kill   %s remove" % [_key_name("agent_follow"), _key_name("agent_control"), _key_name("agent_kill"), _key_name("agent_remove")])
	return "\n".join(lines)


## Current keyboard/mouse key of an action, for on-screen hints
func _key_name(action: String) -> String:
	return ConfigurationSettings.event_to_text(ConfigurationSettings.get_event(action, ConfigurationSettings.Slot.KEYBOARD_MOUSE))
