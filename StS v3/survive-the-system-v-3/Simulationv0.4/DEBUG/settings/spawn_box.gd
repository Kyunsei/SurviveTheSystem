extends ScrollContainer
## Spawn palette (Godot 4).
## 1. Shows every entity of `codex` as a sprite button, in a grid.
## 2. Click a button to select it (on), click it again to deselect (off).
## 3. While one is selected, a semi-transparent "ghost" of its sprite follows the cursor on the ground.
## 4. Left click in the world spawns it there -> _spawn(entry, position) (empty, for you to fill).
## Esc also deselects.
##
## Each codex entry can be a Dictionary or an object (Resource, Node, your species class...)
## with these fields:
##   sprite: Texture2D                 (required)
##   name or species_name: String      (optional, shown under the icon and as a tooltip)
##   hframes, vframes: int             (optional, for sprite sheets: the first frame is used)
##   ghost_scale: float                (optional, ghost size multiplier, default 1)

signal entry_selected(entry)                       # null when deselected
signal spawn_requested(entry, position: Vector3)

var codex: ALIFE_CODEX 
var sp_array :Array[ALIFE]
var alifemanager: AlifeManager
@export var columns := 4
@export var cell_size := Vector2(64, 72)
@export var show_names := true
@export var name_font_size := 10

@export_group("Ghost")
@export var ghost_alpha := 0.5
@export var ghost_pixel_size := 0.01               # same as the renderer's pixel_size
@export var ground_y := 0.0

var selected = null                                # the selected codex entry, or null

var _grid := GridContainer.new()
var _group := ButtonGroup.new()
var _ghost := Sprite3D.new()

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
	refresh()


## Rebuild the buttons. Called automatically when `codex` is assigned.
func refresh() -> void:
	deselect()
	for c in _grid.get_children():
		c.queue_free()
	for i in sp_array.size():
		_grid.add_child(_make_button(sp_array[i], i))


func deselect() -> void:
	var b := _group.get_pressed_button()
	if b != null:
		b.button_pressed = false                   # emits toggled(false) -> _set_selected(null)
	else:
		_set_selected(null)


## --- Fill this in ------------------------------------------------------------------
## Called on left click in the world while an entity is selected.
func _spawn(entry, position: Vector3) -> void:
	alifemanager.species_array[entry.species_id].Build_New_Life(position)
	



# --- Input ---------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if selected == null:
		return

	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var p = _mouse_on_ground()
		if p != null:
			_spawn(selected, p)
			spawn_requested.emit(selected, p)
		get_viewport().set_input_as_handled()

	elif event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == KEY_ESCAPE:
		deselect()
		get_viewport().set_input_as_handled()


# --- Ghost ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if selected == null:
		_ghost.visible = false
		return
	var p = _mouse_on_ground()
	var over_palette := get_global_rect().has_point(get_viewport().get_mouse_position())
	_ghost.visible = p != null and not over_palette
	if p != null:
		_ghost.global_position = p


func _build_ghost() -> void:
	_ghost.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_ghost.modulate = Color(1, 1, 1, ghost_alpha)
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)


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
