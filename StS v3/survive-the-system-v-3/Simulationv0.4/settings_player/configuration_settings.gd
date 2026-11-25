extends Node

const SAVE_PATH := "user://settings.cfg"
const REMAPPABLE := ["up", "down","right","left",
"jump","dash","sprint",
"pick_up", "Drop", "throw", 
"Action", "use","eat","attack",
"look_up","look_down","look_left","look_right", "Camera_zoom_in", "Camera_zoom_out",
"agent_follow", "agent_kill","agent_control", "sim_pause", "menu_toggle", "controls_open","agent_remove"]
enum Slot { KEYBOARD_MOUSE, CONTROLLER }
#to be added in settings one day:
# view_north, view_camera, view_first_person, camera_rise, camera_lower, free_cursor, overlay_toggle
func _ready() -> void:
	load_bindings()

# Which slot does an event belong to?
func slot_of(e: InputEvent) -> int:
	if e is InputEventKey or e is InputEventMouseButton:
		return Slot.KEYBOARD_MOUSE
	if e is InputEventJoypadButton or e is InputEventJoypadMotion:
		return Slot.CONTROLLER
	return -1

func get_event(action: String, slot: int) -> InputEvent:
	for e in InputMap.action_get_events(action):
		if slot_of(e) == slot:
			return e
	return null

# Replace the binding in the event's slot and keep the other slot
func set_event(action: String, event: InputEvent, save := true) -> void:
	var slot := slot_of(event)
	for e in InputMap.action_get_events(action):
		if slot_of(e) == slot:
			InputMap.action_erase_event(action, e)
	InputMap.action_add_event(action, event)
	if save:
		save_bindings()

func save_bindings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH) # keeps any other settings already saved in the file
	for action in REMAPPABLE:
		# ConfigFile can store InputEvent objects directly (project.godot does the same)
		config.set_value("controls", action, InputMap.action_get_events(action))
	config.save(SAVE_PATH)

func load_bindings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return # first launch: keep the defaults
	for action in REMAPPABLE:
		var events = config.get_value("controls", action, null)
		if events is Array: # skips the old int format from the previous version
			InputMap.action_erase_events(action)
			for e in events:
				InputMap.action_add_event(action, e)

func reset_to_defaults() -> void:
	InputMap.load_from_project_settings()
	save_bindings()

# Readable names for the menu (and for on-screen button prompts)
func event_to_text(e: InputEvent) -> String:
	if e == null:
		return "Unbound"
	if e is InputEventKey:
		# Shows the key's name on the player's own keyboard layout
		var k := DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
		return OS.get_keycode_string(k)
	if e is InputEventMouseButton:
		match e.button_index:
			MOUSE_BUTTON_LEFT: return "Left Click"
			MOUSE_BUTTON_RIGHT: return "Right Click"
			MOUSE_BUTTON_MIDDLE: return "Middle Click"
			MOUSE_BUTTON_WHEEL_UP: return "Wheel Up"
			MOUSE_BUTTON_WHEEL_DOWN: return "Wheel Down"
			MOUSE_BUTTON_XBUTTON1: return "Mouse 4"
			MOUSE_BUTTON_XBUTTON2: return "Mouse 5"
		return "Mouse %d" % e.button_index
	if e is InputEventJoypadButton:
		var names := ["A", "B", "X", "Y", "Back", "Guide", "Start",
			"L3", "R3", "LB", "RB", "D-Pad Up", "D-Pad Down", "D-Pad Left", "D-Pad Right"]
		if e.button_index >= 0 and e.button_index < names.size():
			return names[e.button_index]
		return "Button %d" % e.button_index
	if e is InputEventJoypadMotion:
		var neg: bool = e.axis_value < 0
		match e.axis:
			JOY_AXIS_LEFT_X: return "Left Stick " + ("Left" if neg else "Right")
			JOY_AXIS_LEFT_Y: return "Left Stick " + ("Up" if neg else "Down")
			JOY_AXIS_RIGHT_X: return "Right Stick " + ("Left" if neg else "Right")
			JOY_AXIS_RIGHT_Y: return "Right Stick " + ("Up" if neg else "Down")
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
		return "Axis %d %s" % [e.axis, "-" if neg else "+"]
	return e.as_text()
