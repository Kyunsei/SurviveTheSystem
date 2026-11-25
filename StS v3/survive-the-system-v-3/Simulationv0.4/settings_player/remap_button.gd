extends Button
class_name RemapButton

@export var action: String
@export_enum("Keyboard/Mouse", "Controller") var slot := 0

const DEADZONE := 0.5 # how far a stick or trigger must move before it counts

func _ready() -> void:
	toggle_mode = true
	update_text()

func _toggled(on: bool) -> void:
	if on:
		text = "Press a key or click..." if slot == 0 else "Press a button..."
	else:
		update_text()

func _input(event: InputEvent) -> void:
	if not button_pressed:
		return
	# Esc cancels
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		button_pressed = false
		get_viewport().set_input_as_handled()
		return
	var binding := make_binding(event)
	if binding:
		ConfigurationSettings.set_event(action, binding)
		button_pressed = false
		get_viewport().set_input_as_handled()

# Build a clean event from the raw input, or return null to ignore it
func make_binding(event: InputEvent) -> InputEvent:
	if slot == 0: # Keyboard/Mouse
		if event is InputEventKey and event.pressed and not event.echo:
			var e := InputEventKey.new()
			e.physical_keycode = event.physical_keycode
			return e
		if event is InputEventMouseButton and event.pressed:
			var e := InputEventMouseButton.new()
			e.button_index = event.button_index
			return e
	else: # Controller
		if event is InputEventJoypadButton and event.pressed:
			var e := InputEventJoypadButton.new()
			e.button_index = event.button_index
			e.device = -1 # works on any connected controller
			return e
		if event is InputEventJoypadMotion and abs(event.axis_value) > DEADZONE:
			var e := InputEventJoypadMotion.new()
			e.axis = event.axis
			e.axis_value = sign(event.axis_value) # stick direction (+1 or -1)
			e.device = -1
			return e
	return null

func update_text() -> void:
	text = ConfigurationSettings.event_to_text(ConfigurationSettings.get_event(action, slot))
