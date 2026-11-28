class_name AgentPicker
extends Node
## Observing the world (works with PlayerController and FlyCamera).
##
## Hover:        the mouse is always visible: hovering an agent outlines it + tooltip
## agent_follow  (F):  follow the hovered agent | while following: stop following
## agent_control (C):  take control of the hovered (else followed) agent | again: release it
## agent_kill    (K):  kill the hovered agent
## sim_pause     (P):  pause / resume the simulation
## menu_toggle   (O):  open / close the menu
##
## The Controls button / remap menu (F1) is in PlayerController.
## The keys are Input Map actions, so they can be changed in the remap menu
## (add them to Settings.REMAPPABLE).
##
## Also owns the outline (one per species material), so it decides what is outlined:
##   controller's target > carried agent > hovered agent > followed agent
## Taking / releasing control (C) is here; playing the agent (WASD, carrying...) is in
## PlayerController.
## While controlling an agent: no hover, no tooltip, no follow / kill / remove
## (pause, menu and the Controls menu still work).

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
@export var max_sprite_height := 3.0           # minimum; the real tallest sprite is measured
@export var max_pick_distance := 300.0        # world units: longest stretch of ray searched
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

func _ready() -> void:
	_layer.layer = 90
	add_child(_layer)
	_build_tooltip()
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

	elif event.is_action_pressed("sim_pause"):
		if sim_manager.simulation_speed == 0:
			sim_manager.simulation_speed = old_speed
		else:
			old_speed = sim_manager.simulation_speed
			sim_manager.simulation_speed = 0
		get_viewport().set_input_as_handled()

	# Take / release control (works in control mode too, to release)
	if not get_viewport().is_input_handled() and event.is_action_pressed("agent_control"):
		if _toggle_control():
			get_viewport().set_input_as_handled()
		return

	# Agent actions: off in control mode (the keys stay free for the PlayerController)
	if get_viewport().is_input_handled() or _actions_off():
		return

	if event.is_action_pressed("agent_follow"):
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


## agent_control: release, or take the hovered (else followed) agent. True if something happened.
func _toggle_control() -> bool:
	if controller == null or DialogueBox.is_open:
		return false                               # no controller, or talking
	if controller.is_controlling():
		controller.release_control()
	elif hovered_species != null:
		controller.take_control(hovered_species, hovered_index)
	elif followed_species != null:
		controller.take_control(followed_species, followed_index)
	else:
		return false
	return true


## True while an agent is controlled: hover, tooltip and agent actions are off.
func _actions_off() -> bool:
	return controller != null and controller.is_controlling()


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
	# Hover (not while the mouse turns the view, not in control mode)
	var sp = null
	var i := -1
	if not _actions_off() and not camera.is_dragging() and not camera.is_mouse_look():
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
	alifemanager.when_free(func(): sp.current_energy_array[i] = -1.0)   # not mid-tick
	agent_killed.emit(sp, i)
	
func _remove(sp, i: int) -> void:
	alifemanager.when_free(func(): sp.Remove_Life(i))   # a pipelined tick may be running


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
## Walks the grid cells along the cursor ray (nearest first), only where the ray is
## between the ground and the tallest sprite, and tests each agent's sprite on screen.
func _pick_at(screen_pos: Vector2) -> Array:
	var am := alifemanager
	var cam := get_viewport().get_camera_3d()
	if cam == null or am == null or am.global_entity_count == 0:
		return []

	_update_sprite_sizes()
	var max_h := maxf(_max_height, 0.1)

	# 1. The part of the ray where sprites can be: 0 <= y <= tallest sprite
	var from := cam.project_ray_origin(screen_pos)
	var dir := cam.project_ray_normal(screen_pos)
	# (the camera can be any height: max_pick_distance only limits how long that part is,
	# e.g. a ray grazing the ground far away)
	var t0 := 0.0
	var t1 := INF
	if absf(dir.y) > 1e-6:
		var ta := (0.0 - from.y) / dir.y
		var tb := (max_h - from.y) / dir.y
		t0 = maxf(0.0, minf(ta, tb))
		t1 = maxf(ta, tb)
	elif from.y < 0.0 or from.y > max_h:
		return []                                    # level ray, above or below every sprite
	t1 = minf(t1, t0 + max_pick_distance)
	if t1 < t0:
		return []

	# 2. Grid cells along that part, + a margin for the sprites' width
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var vm := WorldWrap.view_mask()
	var wrap_x := vm.x > 0.0
	var wrap_z := vm.z > 0.0
	var step := minf(cs.x, cs.z) * 0.5
	var ring := 1 + ceili(_max_half_width / minf(cs.x, cs.z))
	var cells: Array[int] = []
	var seen := {}
	var t := t0
	while t <= t1 + step:
		var q := from + dir * minf(t, t1)
		var gx := floori(q.x / cs.x)
		var gz := floori(q.z / cs.z)
		for dz in range(-ring, ring + 1):
			var z := gz + dz
			if wrap_z: z = posmod(z, D)
			elif z < 0 or z >= D: continue
			for dx in range(-ring, ring + 1):
				var x := gx + dx
				if wrap_x: x = posmod(x, W)
				elif x < 0 or x >= W: continue
				var key := x + W * z
				if seen.has(key):
					continue
				seen[key] = true
				for y in H:
					cells.append(x + W * (y + H * z))
		t += step

	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var active: PackedInt32Array = am.global_active
	var offs: PackedInt32Array = am.global_species_offset

	# 3. Test each candidate's sprite on screen; keep the one closest to the camera
	var best := -1
	var best_depth := INF
	var cam_pos := cam.global_position
	var cam_fwd := -cam.global_basis.z
	var near := cam.near * 1.5
	var center := camera.get_wrap_center()
	for cell in cells:
		for k in range(cell_start[cell], cell_start[cell + 1]):
			var j: int = cell_items[k]
			if active[j] == 0:
				continue
			var s := offs.bsearch(j, false) - 1
			var sp = am.species_array[s]
			var local := j - offs[s]
			var h: float = _sprite_h[s] * (sp.current_size[local] if _scales[s] else 1.0)
			if h <= 0.0:
				continue

			# The copy of the agent that is actually drawn
			var foot: Vector3 = WorldWrap.curve(
					WorldWrap.nearest_image(sorted_pos[k], center), center)
			var top := foot + Vector3(0.0, h, 0.0)
			# Zoomed in, a tall sprite can pass behind the camera: keep only the visible
			# part of it (cut at the near plane), else its screen position is garbage
			var df := (foot - cam_pos).dot(cam_fwd) - near
			var dt := (top - cam_pos).dot(cam_fwd) - near
			if df <= 0.0 and dt <= 0.0:
				continue                                 # all of it behind the camera
			var p0 := foot
			var p1 := top
			if df <= 0.0:
				p0 = foot.lerp(top, df / (df - dt) + 0.001)
			elif dt <= 0.0:
				p1 = foot.lerp(top, df / (df - dt) - 0.001)
			var a := cam.unproject_position(p0)
			var b := cam.unproject_position(p1)
			var full_px := a.distance_to(b) * h / maxf(p0.distance_to(p1), 1e-6)
			var half_w := 0.5 * _aspect[s] * full_px + pick_margin_px
			if _dist_to_segment(screen_pos, a, b) > half_w:
				continue

			var depth := cam_pos.distance_squared_to(foot)
			if depth < best_depth:
				best_depth = depth
				best = j

	if best < 0:
		return []
	return split_id(best)


# Per species: sprite height at size 1, width / height, grows with size; refreshed now and then
var _sprite_h := PackedFloat32Array()
var _aspect := PackedFloat32Array()
var _scales: Array[bool] = []
var _max_height := 0.0
var _max_half_width := 0.0
var _sizes_timer := 0.0

func _update_sprite_sizes() -> void:
	var n := alifemanager.species_array.size()
	var now := Time.get_ticks_msec() / 1000.0
	if _sprite_h.size() == n and now - _sizes_timer < 0.5:
		return
	_sizes_timer = now
	_sprite_h.resize(n)
	_aspect.resize(n)
	_scales.resize(n)
	_max_height = max_sprite_height
	_max_half_width = 0.0
	for s in n:
		var sp = alifemanager.species_array[s]
		var qs: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
		var mat: ShaderMaterial = sp.renderer3D.material_override
		var scales = mat.get_shader_parameter("scale_sprite_with_size")
		_scales[s] = scales == null or scales == true      # shader default: true
		_sprite_h[s] = qs.y * sp.sprite_scale
		_aspect[s] = qs.x / maxf(qs.y, 1e-6)
		# Tallest / widest sprite of this species right now
		var big := 1.0
		if _scales[s]:
			big = 0.0
			for i in sp.entity_count:
				if sp.active_alife_array[i] != 0:
					big = maxf(big, sp.current_size[i])
		var hmax: float = _sprite_h[s] * big
		_max_height = maxf(_max_height, hmax)
		_max_half_width = maxf(_max_half_width, hmax * _aspect[s] * 0.5)


func _dist_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len2 := ab.length_squared()
	if len2 < 1e-6:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


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
