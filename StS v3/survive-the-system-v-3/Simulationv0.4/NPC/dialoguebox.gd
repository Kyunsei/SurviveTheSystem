extends CanvasLayer
## Dialogue box: add it as an AUTOLOAD named "DialogueBox"
## (Project Settings > Globals > Autoload: this script, Node Name "DialogueBox").
##
## DialogueBox.start(npc_data, first_time, on_done) shows the lines one by one with a
## typing effect. Action / Space / Enter / left click: finish the line, then next line;
## after the last one it closes and calls on_done. Esc: close now.
## While open: the cursor is free and the game doesn't get those keys or the mouse
## (PlayerController also stops the agent: see is_open).

signal started(npc: NpcData)
signal finished(npc: NpcData)

@export var chars_per_second := 45.0

var is_open := false

var _npc: NpcData = null
var _lines := PackedStringArray()
var _index := 0
var _shown := 0.0                              # characters shown of the current line
var _on_done := Callable()
var _prev_mouse := Input.MOUSE_MODE_VISIBLE

var _panel := PanelContainer.new()
var _portrait := TextureRect.new()
var _name := Label.new()
var _text := Label.new()
var _hint := Label.new()


func _ready() -> void:
	layer = 95                                 # above the HUD, under the menus
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


## Starts a conversation. first_time: first_lines, else repeat_lines (if any).
func start(npc: NpcData, first_time := true, on_done := Callable()) -> void:
	if npc == null:
		return
	_npc = npc
	_lines = npc.first_lines if (first_time or npc.repeat_lines.is_empty()) else npc.repeat_lines
	if _lines.is_empty():
		if on_done.is_valid():
			on_done.call()
		return
	_on_done = on_done
	_index = 0
	is_open = true
	_prev_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_name.text = npc.display_name
	_portrait.texture = npc.portrait
	_portrait.visible = npc.portrait != null
	_show_line()
	_panel.visible = true
	started.emit(npc)


## Closes now (Esc, or from code).
func close() -> void:
	if not is_open:
		return
	is_open = false
	_panel.visible = false
	Input.mouse_mode = _prev_mouse
	var npc := _npc
	var done := _on_done
	_npc = null
	_on_done = Callable()
	if done.is_valid():
		done.call()
	finished.emit(npc)


func _show_line() -> void:
	_text.text = _lines[_index]
	_shown = 0.0
	_text.visible_characters = 0
	_hint.text = "▶" if _index < _lines.size() - 1 else "■"


## Next: finish the typing first, then the next line, then close.
func _advance() -> void:
	if _text.visible_characters < _text.text.length():
		_shown = _text.text.length()
		_text.visible_characters = -1          # whole line at once
		return
	_index += 1
	if _index >= _lines.size():
		close()
	else:
		_show_line()


func _process(delta: float) -> void:
	if not is_open or _text.visible_characters < 0:
		return
	_shown += chars_per_second * delta
	_text.visible_characters = mini(int(_shown), _text.text.length())


func _input(event: InputEvent) -> void:
	if not is_open:
		return
	var next = event.is_action_pressed("ui_accept") \
			or (InputMap.has_action("Action") and event.is_action_pressed("Action")) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if next:
		_advance()
	elif event.is_action_pressed("ui_cancel"):
		close()
	# While talking, the game gets no clicks, no mouse look, no action keys
	if next or event is InputEventMouse or event.is_action_type():
		get_viewport().set_input_as_handled()


func _build() -> void:
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 40
	_panel.offset_right = -40
	_panel.offset_top = -170
	_panel.offset_bottom = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.08, 0.12, 0.92)
	style.border_color = Color(1.0, 0.85, 0.4, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)

	_portrait.custom_minimum_size = Vector2(110, 110)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_portrait)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(col)

	_name.add_theme_font_size_override("font_size", 20)
	_name.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	col.add_child(_name)

	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_size_override("font_size", 17)
	col.add_child(_text)

	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	col.add_child(_hint)
