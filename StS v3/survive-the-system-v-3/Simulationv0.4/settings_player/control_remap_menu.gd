extends Control
class_name SettingsRemapMenu

signal closed

# Optional nicer names. Any action not listed here uses "move_left" -> "Move Left"
const DISPLAY_NAMES := {
	# "jump": "Jump / Confirm",
}

var _buttons: Array[RemapButton] = []
func _ready() -> void:
	# "and_offsets" also clears any leftover size from the editor,
	# which could otherwise push the menu past the screen edge
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(PRESET_FULL_RECT)

	# Outer margin: the panel fills the screen minus this gap, so it can never overflow
	var outer := MarginContainer.new()
	add_child(outer)
	outer.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		outer.add_theme_constant_override("margin_" + side, 24)

	var panel := PanelContainer.new()
	outer.add_child(panel)

	var inner := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inner.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(inner)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inner.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Controls"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)

	# The table goes in a scroll area that takes up all the leftover height
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true # scrolls automatically when you move through it with a controller
	vbox.add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 8)
	center.add_child(grid)

	for header in ["Action", "Keyboard / Mouse", "Controller"]:
		var h := Label.new()
		h.text = header
		h.modulate = Color(1, 1, 1, 0.6)
		grid.add_child(h)

	for action in ConfigurationSettings.REMAPPABLE:
		var label := Label.new()
		label.text = DISPLAY_NAMES.get(action, action.capitalize())
		grid.add_child(label)

		for slot in 2:
			var b := RemapButton.new()
			b.action = action
			b.slot = slot
			b.custom_minimum_size = Vector2(140, 0)
			grid.add_child(b)
			_buttons.append(b)

	# Bottom bar sits outside the scroll area, so it's always visible
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	bottom.add_theme_constant_override("separation", 8)
	vbox.add_child(bottom)

	var reset := Button.new()
	reset.text = "Reset to Defaults"
	reset.pressed.connect(_on_reset)
	bottom.add_child(reset)

	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(_on_back)
	bottom.add_child(back)

	if not _buttons.is_empty():
		_buttons[0].grab_focus.call_deferred()
# Creates the menu on its own CanvasLayer, so it always draws on top of everything

static func open(parent: Node) -> SettingsRemapMenu:
	var layer := CanvasLayer.new()
	layer.layer = 10
	parent.add_child(layer)

	var menu := SettingsRemapMenu.new()
	layer.add_child(menu)
	menu.closed.connect(layer.queue_free) # removes the layer when the menu closes
	return menu
		
func _unhandled_input(event: InputEvent) -> void:
	# Esc or B closes the menu. While a button is waiting for input it
	# handles the event first, so this won't fire then.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_reset() -> void:
	ConfigurationSettings.reset_to_defaults()
	for b in _buttons:
		b.update_text()

func _on_back() -> void:
	closed.emit()
	queue_free()
