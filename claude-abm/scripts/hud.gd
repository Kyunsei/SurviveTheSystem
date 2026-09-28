extends CanvasLayer
## 3D explorer HUD: crosshair, status, agent card, messages, help and the Esc menu.

const Simulation := preload("res://scripts/simulation.gd")
const HELP := """WASD move   Shift sprint   Space jump / swim   Mouse look   V first/third person
Left click strike   Right click feed   E sow grass and flowers   C breed 8 clones   T follow / stop
G presence: invisible / predator / lure / prey   1-5 colours   [ ] sim speed   P pause sim
Tab 2D map (the simulation keeps running)   H hide help   Esc menu"""

var explorer: Node

var _status: Label
var _card: PanelContainer
var _card_title: Label
var _card_swatch: ColorRect
var _card_energy: ProgressBar
var _card_text: Label
var _message: Label
var _message_time := 0.0
var _health: ProgressBar
var _help: Label
var _loading: Label
var _cross: Control
var _menu: Control
var _tps_label: Label
var _stats := {}


func _ready() -> void:
	_cross = Crosshair.new()
	_cross.set_anchors_preset(Control.PRESET_CENTER)
	add_child(_cross)

	_status = _panel_label(Vector2(12, 12))
	_status.text = ""

	_card = PanelContainer.new()
	_card.add_theme_stylebox_override("panel", _style())
	_card.anchor_top = 1.0
	_card.anchor_bottom = 1.0
	_card.offset_left = 12
	_card.offset_top = -12
	_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_card.custom_minimum_size.x = 330
	add_child(_card)
	var cb := VBoxContainer.new()
	_card.add_child(cb)
	var head := HBoxContainer.new()
	cb.add_child(head)
	_card_swatch = ColorRect.new()
	_card_swatch.custom_minimum_size = Vector2(18, 18)
	head.add_child(_card_swatch)
	_card_title = Label.new()
	_card_title.add_theme_font_size_override("font_size", 18)
	head.add_child(_card_title)
	_card_energy = ProgressBar.new()
	_card_energy.max_value = 1.0
	_card_energy.show_percentage = false
	_card_energy.custom_minimum_size.y = 10
	cb.add_child(_card_energy)
	_card_text = Label.new()
	_card_text.add_theme_font_size_override("font_size", 13)
	cb.add_child(_card_text)
	_card.visible = false

	_message = Label.new()
	_message.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_message.offset_top = 70
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.add_theme_font_size_override("font_size", 22)
	_message.add_theme_color_override("font_outline_color", Color.BLACK)
	_message.add_theme_constant_override("outline_size", 6)
	add_child(_message)

	_health = ProgressBar.new()
	_health.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_health.offset_left = -150
	_health.offset_right = 150
	_health.offset_top = 20
	_health.offset_bottom = 42
	_health.max_value = 100.0
	_health.visible = false
	add_child(_health)

	_help = Label.new()
	_help.text = HELP
	_help.anchor_left = 1.0
	_help.anchor_right = 1.0
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_help.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_help.offset_right = -12
	_help.offset_bottom = -12
	_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_help.add_theme_font_size_override("font_size", 13)
	_help.add_theme_color_override("font_outline_color", Color.BLACK)
	_help.add_theme_constant_override("outline_size", 4)
	add_child(_help)

	_loading = Label.new()
	_loading.text = "Growing a world..."
	_loading.set_anchors_preset(Control.PRESET_CENTER)
	_loading.add_theme_font_size_override("font_size", 28)
	add_child(_loading)

	_build_menu()


func on_stats(s: Dictionary) -> void:
	_stats = s


func set_loading(on: bool) -> void:
	_loading.visible = on


func toggle_help() -> void:
	_help.visible = not _help.visible


func flash(text: String) -> void:
	_message.text = text
	_message_time = 2.5


func set_health(value: float, show: bool) -> void:
	_health.visible = show
	_health.value = value


func set_aiming(on: bool) -> void:
	(_cross as Crosshair).active = on
	_cross.queue_redraw()


func set_status(lines: PackedStringArray) -> void:
	var s := _stats
	if not s.is_empty():
		lines.append("World: %s alive  (%s herbivores, %s carnivores)" % [
				_fmt(s.alive), _fmt(s.herbivores), _fmt(s.carnivores)])
		lines.append("Brains: %s utility, %s neural   generation %d" % [
				_fmt(s.utility), _fmt(s.neural), s.max_generation])
		lines.append("Plant cover: " + preload("res://scripts/ui.gd")._forms(s.plant_forms))
	lines.append("%d fps" % Engine.get_frames_per_second())
	_status.text = "\n".join(lines)


## `a` is the inspected agent (see explorer.gd), or empty to hide the card.
func show_agent(a: Dictionary) -> void:
	_card.visible = not a.is_empty()
	if a.is_empty():
		return
	var diet: float = a.genes[2]
	var kind := "Herbivore" if diet < 0.33 else ("Omnivore" if diet < 0.66 else "Carnivore")
	_card_title.text = "  %s  ·  %s brain%s" % [kind, "Neural" if a.neural else "Utility",
			"  ·  FOLLOWING" if a.tracked else ""]
	_card_swatch.color = Color.from_hsv(a.hue, 0.75, 1.0)
	_card_energy.value = clampf(a.energy / maxf(a.genes[3], 0.1), 0.0, 1.0)
	var g: Array = a.genes
	var lines := [
		"Doing: %s    energy %.1f / %.1f    %.0f m away" % [Simulation.ACTIONS[mini(a.action, Simulation.ACTIONS.size() - 1)], a.energy, g[3], a.distance],
		"Age %d ticks    generation %d    agent #%d" % [a.age, a.generation, a.index],
		"Size %.2f   speed %.2f   diet %.2f   sense %.2f" % [g[0], g[1], g[2], g[6]],
		"Child share %.2f   mutation %.3f   species hue %.2f" % [g[7], g[4], g[5]],
		"Vision %.0f m   plant-toxin tolerance (detox) %.2f" % [5.0 + 8.0 * g[6], g[16]],
	]
	if not a.neural:
		lines.append("Utility weights: graze %.1f hunt %.1f flee %.1f flock %.1f" % [g[8], g[9], g[10], g[11]])
		lines.append("   wander %.1f rest %.1f scavenge %.1f   hunger curve %.1f" % [g[12], g[13], g[14], g[15]])
		lines.append("   hide %.1f care %.1f mark %.1f home %.1f recall %.1f" % [g[17], g[18], g[19], g[20], g[21]])
	lines.append("Alarm calls %.2f   care for young %.2f" % [g[22], g[23]])
	_card_text.text = "\n".join(lines)


func is_menu_open() -> bool:
	return _menu.visible


func open_menu(on: bool) -> void:
	_menu.visible = on
	_tps_label.text = "Simulation speed: %d ticks/s" % int(explorer.ticks_per_second)


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		_message.modulate.a = clampf(_message_time, 0.0, 1.0)


func _build_menu() -> void:
	_menu = ColorRect.new()
	(_menu as ColorRect).color = Color(0, 0, 0, 0.55)
	_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.visible = false
	add_child(_menu)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(20))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 360
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.text = "3D Explorer"
	title.add_theme_font_size_override("font_size", 26)
	box.add_child(title)

	_button(box, "Resume", func() -> void: explorer.resume())
	_tps_label = Label.new()
	box.add_child(_tps_label)
	var tps := HSlider.new()
	tps.min_value = 1
	tps.max_value = 40
	tps.value = 10
	tps.value_changed.connect(func(v: float) -> void:
		explorer.ticks_per_second = v
		_tps_label.text = "Simulation speed: %d ticks/s" % int(v))
	box.add_child(tps)
	var vd_label := Label.new()
	vd_label.text = "Creature view distance: 200 m"
	box.add_child(vd_label)
	var vd := HSlider.new()
	vd.min_value = 50
	vd.max_value = 400
	vd.value = 200
	vd.value_changed.connect(func(v: float) -> void:
		explorer.sim.player.vis_radius = v
		vd_label.text = "Creature view distance: %d m" % int(v))
	box.add_child(vd)
	var colors := OptionButton.new()
	for c in Simulation.COLOR_MODES:
		colors.add_item("Colour: " + c)
	colors.item_selected.connect(func(i: int) -> void: explorer.sim.color_mode = i)
	box.add_child(colors)
	var brains := OptionButton.new()
	for m in ["Brains on reset: Utility AI", "Brains on reset: Neural network", "Brains on reset: Mixed"]:
		brains.add_item(m)
	brains.select(Launch.brain_mode)
	brains.item_selected.connect(func(i: int) -> void:
		Launch.brain_mode = i
		explorer.sim.brain_mode = i)
	box.add_child(brains)
	_button(box, "Switch to the 2D map (Tab)", func() -> void: explorer.switch_to_2d())
	_button(box, "Save world", func() -> void:
		Launch.save_world()
		flash("Saving world..."))
	_button(box, "Reset world", func() -> void: explorer.reset_world())
	_button(box, "Back to main menu", func() -> void: Launch.go(Launch.MENU))


func _button(box: Control, text: String, f: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 36
	b.pressed.connect(f)
	box.add_child(b)


func _panel_label(pos: Vector2) -> Label:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style())
	panel.position = pos
	add_child(panel)
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 13)
	panel.add_child(l)
	return l


func _style(margin := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0.05, 0.06, 0.08, 0.72)
	s.set_corner_radius_all(6)
	s.set_content_margin_all(margin)
	return s


static func _fmt(n: int) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


class Crosshair extends Control:
	var active := false

	func _draw() -> void:
		var c := Color(1.0, 0.85, 0.3) if active else Color(1, 1, 1, 0.8)
		draw_arc(Vector2.ZERO, 7.0 if active else 4.0, 0, TAU, 24, c, 2.0)
		draw_circle(Vector2.ZERO, 1.5, c)
