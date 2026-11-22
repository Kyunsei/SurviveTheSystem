extends ScrollContainer
## Spawn palette (Godot 4).
## 1. Shows every species of the codex as a sprite button, in a grid.
## 2. Click a button to select it (on), click it again to deselect (off).
##    Right click (anywhere) or Esc also deselects.
## 3. While one is selected, a semi-transparent "ghost" follows the cursor on the ground,
##    with a ring showing the brush radius.
## 4. Left click spawns; keep it pressed to keep painting (spawn_rate strokes per second).
##    Each stroke spawns `brush_count` entities at random spots inside the brush radius,
##    never closer than `min_distance` to another entity.
## A small panel under the palette lets you tune all of this during the game.

signal entry_selected(entry)                       # null when deselected
signal spawn_requested(entry, position: Vector3)

var codex: ALIFE_CODEX
var sp_array :Array[ALIFE]
var alifemanager: AlifeManager
@export var columns := 4
@export var cell_size := Vector2(64, 72)
@export var show_names := true
@export var name_font_size := 10

@export_group("Brush (defaults, tunable in game)")
@export var hold_to_paint := true                  # keep the click pressed to keep spawning
@export var spawn_rate := 8.0                      # strokes per second while pressed
@export var brush_radius := 0.0                    # 0 = exactly at the cursor
@export var brush_count := 1                       # entities per stroke
@export var min_distance := 0.0                    # 0 = no limit
@export var min_distance_same_species := true      # only count entities of the same species
## Where the tuning panel goes. Empty: added right after this node in the same parent.
@export var controls_parent: Control

@export_group("Ghost")
@export var ghost_alpha := 0.5
@export var ghost_pixel_size := 0.01               # same as the renderer's pixel_size
@export var ground_y := 0.0

var selected = null                                # the selected codex entry, or null

var _grid := GridContainer.new()
var _group := ButtonGroup.new()
var _ghost := Sprite3D.new()
var _ring := MeshInstance3D.new()                  # brush radius on the ground
var _painting := false                             # left button held in the world
var _stroke_timer := 0.0
var _recent: Array = []                            # [position, time] of recent spawns


'func _ready() -> void:
	codex = ALIFE_CODEX.new()
	init()'

func init() -> void:
	sp_array =codex.species_list
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_grid.columns = columns
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_grid)
	_group.allow_unpress = true                    # clicking the selected button turns it off
	_build_ghost()
	_build_ring()
	_build_controls.call_deferred()                # the parent may still be busy adding children
	refresh()


## Rebuild the buttons.
func refresh() -> void:
	deselect()
	for c in _grid.get_children():
		c.queue_free()
	for i in sp_array.size():
		_grid.add_child(_make_button(sp_array[i], i))


func deselect() -> void:
	_painting = false
	var b := _group.get_pressed_button()
	if b != null:
		b.button_pressed = false                   # emits toggled(false) -> _set_selected(null)
	else:
		_set_selected(null)


## --- Spawn one entity ----------------------------------------------------------------
func _spawn(entry, position: Vector3) -> void:
	alifemanager.species_array[entry.species_id].Build_New_Life(position)


# --- Input ---------------------------------------------------------------------

## Right click deselects. Handled in _input so it runs before the camera's right-drag.
## Button releases are caught here too, even when released over the UI.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_painting = false
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and selected != null:
		deselect()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if selected == null:
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_stroke()                                  # first stroke right away
		_painting = hold_to_paint
		_stroke_timer = 1.0 / maxf(spawn_rate, 0.1)
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		deselect()
		get_viewport().set_input_as_handled()


# --- Painting ------------------------------------------------------------------

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	while not _recent.is_empty() and now - _recent[0][1] > 1.0:
		_recent.pop_front()                        # older spawns are in the grid by now

	if selected == null:
		_ghost.visible = false
		_ring.visible = false
		return

	var p = _mouse_on_ground()
	var over_ui := get_viewport().gui_get_hovered_control() != null
	var on_ground := p != null and not over_ui
	_ghost.visible = on_ground
	_ring.visible = on_ground and brush_radius > 0.0
	if p != null:
		_ghost.global_position = p
		_ring.global_position = p + Vector3(0.0, 0.03, 0.0)
		_ring.scale = Vector3(brush_radius, 1.0, brush_radius)

	# Keep painting while the button is held (not over the UI)
	if _painting and on_ground:
		_stroke_timer -= delta
		while _stroke_timer <= 0.0:
			_stroke()
			_stroke_timer += 1.0 / maxf(spawn_rate, 0.1)


## One stroke: brush_count entities at random spots in the brush, respecting min_distance.
func _stroke() -> void:
	var center = _mouse_on_ground()
	if center == null or selected == null:
		return
	var tries := brush_count * 6                   # give up on spots that are too crowded
	var placed := 0
	while placed < brush_count and tries > 0:
		tries -= 1
		var pos: Vector3 = center
		if brush_radius > 0.0:
			# Uniform inside the disc (sqrt: not bunched in the middle)
			var a := randf() * TAU
			var r := sqrt(randf()) * brush_radius
			pos += Vector3(cos(a) * r, 0.0, sin(a) * r)
		pos = _into_world(pos)
		if min_distance > 0.0 and _too_close(pos):
			continue
		_spawn(selected, pos)
		spawn_requested.emit(selected, pos)
		_recent.append([pos, Time.get_ticks_msec() / 1000.0])
		placed += 1


## Inside the world: wrapped on wrapped axes, clamped on the others.
func _into_world(p: Vector3) -> Vector3:
	p = WorldWrap.wrap_into(p)
	var ws := WorldWrap.size
	if WorldWrap.mask.x == 0.0: p.x = clampf(p.x, 0.0, ws.x)
	if WorldWrap.mask.z == 0.0: p.z = clampf(p.z, 0.0, ws.z)
	return p


## True if an entity (or a spawn from the last second, not in the grid yet) is too close.
func _too_close(pos: Vector3) -> bool:
	var r2 := min_distance * min_distance
	for rc in _recent:
		if _flat_dist2(rc[0], pos) < r2:
			return true

	var am := alifemanager
	if am == null or am.cell_start.is_empty():
		return false
	var W: int = am.GRID_W
	var H: int = am.GRID_H
	var D: int = am.GRID_D
	var cs: Vector3 = am.cell_size
	var cell_start: PackedInt32Array = am.cell_start
	var cell_items: PackedInt32Array = am.cell_items
	var sorted_pos: PackedVector3Array = am.sorted_pos
	var active: PackedInt32Array = am.global_active
	var offs: PackedInt32Array = am.global_species_offset
	var lo := 0
	var hi := 1 << 30
	if min_distance_same_species:
		lo = offs[selected.species_id]
		hi = offs[selected.species_id + 1]

	var wx := WorldWrap.mask.x > 0.0
	var wz := WorldWrap.mask.z > 0.0
	var cx := clampi(int(pos.x / cs.x), 0, W - 1)
	var cz := clampi(int(pos.z / cs.z), 0, D - 1)
	var rx := ceili(min_distance / cs.x)
	var rz := ceili(min_distance / cs.z)
	if wx: rx = mini(rx, (W - 1) / 2)
	if wz: rz = mini(rz, (D - 1) / 2)
	for zz in range(cz - rz, cz + rz + 1):
		var z := posmod(zz, D) if wz else zz
		if z < 0 or z >= D:
			continue
		for y in H:
			for xx in range(cx - rx, cx + rx + 1):
				var x := posmod(xx, W) if wx else xx
				if x < 0 or x >= W:
					continue
				var cell := x + W * (y + H * z)
				for k in range(cell_start[cell], cell_start[cell + 1]):
					var j: int = cell_items[k]
					if j < lo or j >= hi or active[j] == 0:
						continue
					if _flat_dist2(sorted_pos[k], pos) < r2:
						return true
	return false


## Distance² on the ground, the short way through wrapped borders.
func _flat_dist2(a: Vector3, b: Vector3) -> float:
	var d := a - b
	var ws := WorldWrap.size
	if WorldWrap.mask.x > 0.0: d.x -= ws.x * roundf(d.x / ws.x)
	if WorldWrap.mask.z > 0.0: d.z -= ws.z * roundf(d.z / ws.z)
	return d.x * d.x + d.z * d.z


# --- Ghost + brush ring ----------------------------------------------------------

func _build_ghost() -> void:
	_ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_ghost.modulate = Color(1, 1, 1, ghost_alpha)
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


func _build_ring() -> void:
	# Unit circle on the ground, scaled by brush_radius
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in 65:
		var a := TAU * k / 64.0
		im.surface_add_vertex(Vector3(cos(a), 0.0, sin(a)))
	im.surface_end()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 1.0, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	_ring.mesh = im
	_ring.material_override = mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring.visible = false
	add_child(_ring)


func _setup_ghost(entry) -> void:
	var tex: Texture2D = _field(entry, "sprite")
	_ghost.texture = tex
	if tex == null:
		return
	_ghost.hframes = int(_field(entry, "hframes", 1))
	_ghost.vframes = int(_field(entry, "vframes", 1))
	_ghost.frame = 0
	_ghost.pixel_size = ghost_pixel_size * float(_field(entry, "ghost_scale", 1.0))
	# Feet on the cursor point, like the real sprites
	var frame_h := tex.get_height() / float(_ghost.vframes)
	_ghost.offset = Vector2(0.0, frame_h * 0.5)


func _mouse_on_ground():
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mp := get_viewport().get_mouse_position()
	return Plane(Vector3.UP, ground_y).intersects_ray(
			cam.project_ray_origin(mp), cam.project_ray_normal(mp))


# --- Tuning panel (under the palette) ----------------------------------------------

func _build_controls() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var hold := CheckBox.new()
	hold.text = "Hold to paint"
	hold.button_pressed = hold_to_paint
	hold.focus_mode = Control.FOCUS_NONE
	hold.toggled.connect(func(on: bool): hold_to_paint = on)
	box.add_child(hold)

	box.add_child(_slider_row("Rate /s", 1.0, 30.0, 1.0, spawn_rate,
			func(v: float): spawn_rate = v))
	box.add_child(_slider_row("Radius", 0.0, 20.0, 0.5, brush_radius,
			func(v: float): brush_radius = v))
	box.add_child(_slider_row("Count", 1.0, 50.0, 1.0, brush_count,
			func(v: float): brush_count = int(v)))
	box.add_child(_slider_row("Min dist", 0.0, 10.0, 0.1, min_distance,
			func(v: float): min_distance = v))

	var same := CheckBox.new()
	same.text = "Min dist: same species only"
	same.button_pressed = min_distance_same_species
	same.focus_mode = Control.FOCUS_NONE
	same.toggled.connect(func(on: bool): min_distance_same_species = on)
	box.add_child(same)

	if controls_parent != null:
		controls_parent.add_child(box)
	elif get_parent() != null:
		var parent := get_parent()
		parent.add_child(box)
		parent.move_child(box, get_index() + 1)    # right after (under, in a VBox) the palette


## Label + slider + value, calling `on_change(value)` when moved.
func _slider_row(title: String, lo: float, hi: float, step_v: float, value: float,
		on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = title
	name_label.custom_minimum_size.x = 64
	name_label.add_theme_font_size_override("font_size", name_font_size + 1)
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step_v
	slider.value = value
	slider.focus_mode = Control.FOCUS_NONE          # never steals the keyboard
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 34
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_font_size_override("font_size", name_font_size + 1)
	value_label.text = _fmt(value, step_v)
	row.add_child(value_label)

	slider.value_changed.connect(func(v: float):
		value_label.text = _fmt(v, step_v)
		on_change.call(v))
	return row


func _fmt(v: float, step_v: float) -> String:
	return "%d" % roundi(v) if step_v >= 1.0 else "%.1f" % v


# --- Buttons -------------------------------------------------------------------

func _make_button(entry, index: int) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = _group
	b.focus_mode = Control.FOCUS_NONE              # never steals Space / Enter from the game
	b.custom_minimum_size = cell_size
	b.icon = _first_frame(entry)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var n := _entry_name(entry, index)
	b.tooltip_text = n
	if show_names:
		b.text = n
		b.clip_text = true
		b.add_theme_font_size_override("font_size", name_font_size)

	b.toggled.connect(_on_toggled.bind(entry))
	return b


func _on_toggled(on: bool, entry) -> void:
	if on:
		_set_selected(entry)
	elif _group.get_pressed_button() == null:      # turned off, and nothing else turned on
		_set_selected(null)


func _set_selected(entry) -> void:
	if entry == selected:
		return
	selected = entry
	if entry != null:
		_setup_ghost(entry)
	else:
		_ghost.visible = false
		_ring.visible = false
	entry_selected.emit(entry)


# --- Helpers -------------------------------------------------------------------

## Reads a field from a Dictionary or an object, with a default if it's missing.
func _field(entry, key: String, default = null):
	if entry is Dictionary:
		return entry.get(key, default)
	if entry is Object:
		var v = entry.get(key)
		return v if v != null else default
	return default


func _entry_name(entry, index: int) -> String:
	var n = _field(entry, "name")
	if n == null:
		n = _field(entry, "species_name")
	return str(n) if n != null else "Entity %d" % index


## First frame of a sprite sheet (or the whole texture if it isn't one).
func _first_frame(entry) -> Texture2D:
	var tex: Texture2D = _field(entry, "sprite")
	if tex == null:
		return null
	var hf := int(_field(entry, "hframes", 1))
	var vf := int(_field(entry, "vframes", 1))
	if hf <= 1 and vf <= 1:
		return tex
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, tex.get_width() / float(hf), tex.get_height() / float(vf))
	return atlas
