extends CanvasLayer
## Side panel: run controls, live parameters, statistics and charts.

signal rebuild_requested

const HISTORY := 400

var sim: Node

var _stats_label: Label
var _graph: PopGraph
var _hues: HueBars
var _mode: OptionButton
var _color: OptionButton
var _pause: Button
var _steps: HSlider
var _steps_label: Label
var _fields: CheckBox
var _pop: SpinBox
var _world: OptionButton


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -340.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.92)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	var title := Label.new()
	title.text = "Evolving Ecosystem"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.text = "waiting for stats..."
	box.add_child(_stats_label)

	_graph = PopGraph.new()
	_graph.custom_minimum_size = Vector2(0, 120)
	box.add_child(_graph)
	_hues = HueBars.new()
	_hues.custom_minimum_size = Vector2(0, 40)
	box.add_child(_hues)

	_section(box, "Run")
	_mode = OptionButton.new()
	for m in ["Utility AI", "Neural network", "Mixed (compete)"]:
		_mode.add_item(m)
	_mode.item_selected.connect(func(i: int) -> void:
		sim.brain_mode = i
		Launch.brain_mode = i)
	_row(box, "Brains", _mode)

	_pop = SpinBox.new()
	_pop.min_value = 1000
	_pop.max_value = 16_000_000
	_pop.step = 1000
	_pop.value_changed.connect(func(v: float) -> void:
		sim.initial_pop = mini(int(v), sim.capacity)
		Launch.initial_pop = int(v))
	_row(box, "Start pop.", _pop)

	var reset := Button.new()
	reset.text = "Reset (R)"
	reset.pressed.connect(func() -> void: sim.reset())
	box.add_child(reset)

	var hb := HBoxContainer.new()
	_pause = Button.new()
	_pause.toggle_mode = true
	_pause.text = "Pause (Space)"
	_pause.toggled.connect(func(on: bool) -> void: sim.paused = on)
	_pause.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(_pause)
	box.add_child(hb)

	_steps_label = Label.new()
	box.add_child(_steps_label)
	_steps = HSlider.new()
	_steps.min_value = 1
	_steps.max_value = 32
	_steps.value_changed.connect(func(v: float) -> void:
		sim.steps_per_frame = int(v)
		_steps_label.text = "Ticks per frame: %d (+/-)" % int(v))
	box.add_child(_steps)

	_section(box, "View")
	_color = OptionButton.new()
	for m in preload("res://scripts/simulation.gd").COLOR_MODES:
		_color.add_item(m)
	_color.item_selected.connect(func(i: int) -> void: sim.color_mode = i)
	_row(box, "Color (1-5)", _color)
	_fields = CheckBox.new()
	_fields.text = "Show plants / carrion"
	_fields.toggled.connect(func(on: bool) -> void: sim.show_fields = on)
	box.add_child(_fields)

	_section(box, "Ecology (live)")
	_slider(box, "sun_energy", "Sun energy /m2", 0.0, 0.006, 0.0001)
	_slider(box, "compute_cost", "Compute cost", 0.0, 0.003, 0.0001)
	_slider(box, "plant_growth", "Plant growth", 0.0, 0.2, 0.005)
	_slider(box, "season_strength", "Season strength", 0.0, 1.0, 0.05)
	_slider(box, "metabolism", "Metabolism", 0.0, 0.05, 0.001)
	_slider(box, "move_cost", "Movement cost", 0.0, 0.05, 0.001)
	_slider(box, "attack_power", "Attack power", 0.0, 3.0, 0.05)
	_slider(box, "plant_efficiency", "Plant efficiency", 0.05, 1.0, 0.05)
	_slider(box, "meat_efficiency", "Meat efficiency", 0.0, 2.0, 0.05)
	_slider(box, "meat_decay", "Carrion decay", 0.0, 0.05, 0.001)
	_slider(box, "max_age", "Max age", 200.0, 10000.0, 100.0)

	_section(box, "Evolution (live)")
	_slider(box, "mutation_scale", "Mutation scale", 0.0, 5.0, 0.1)
	_slider(box, "mate_distance", "Species distance", 0.0, 0.5, 0.01)
	_slider(box, "vision_cost", "Vision cost", 0.0, 0.02, 0.001)
	_slider(box, "detox_cost", "Detox cost", 0.0, 0.1, 0.005)
	_slider(box, "plant_mutation", "Plant mutation", 0.0, 0.15, 0.005)

	_section(box, "World (rebuild)")
	_world = OptionButton.new()
	for s in [512, 1024, 2048, 4096]:
		_world.add_item(str(s))
		_world.set_item_metadata(_world.item_count - 1, s)
	_row(box, "World size", _world)
	var rebuild := Button.new()
	rebuild.text = "Rebuild world"
	rebuild.pressed.connect(_on_rebuild)
	box.add_child(rebuild)

	var save := Button.new()
	save.text = "Save world"
	save.pressed.connect(func() -> void:
		save.disabled = true
		save.text = "Saving..."
		Launch.save_world())
	sim.saved.connect(func(_p: String) -> void:
		save.disabled = false
		save.text = "Saved! Save again")
	box.add_child(save)

	var to3d := Button.new()
	to3d.text = "Walk here in 3D (Tab)"
	to3d.pressed.connect(func() -> void: get_parent().switch_to_3d())
	box.add_child(to3d)

	var menu := Button.new()
	menu.text = "Main menu (Esc)"
	menu.pressed.connect(func() -> void: Launch.go(Launch.MENU))
	box.add_child(menu)

	var help := Label.new()
	help.add_theme_font_size_override("font_size", 11)
	help.modulate = Color(1, 1, 1, 0.6)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD
	help.text = "Drag to pan, wheel to zoom, F to fit, arrows to move. Tab walks the centre of the view in 3D; the simulation keeps running."
	box.add_child(help)

	sim.stats_updated.connect(_on_stats)
	sync_from_sim()


func sync_from_sim() -> void:
	_mode.select(sim.brain_mode)
	_color.select(sim.color_mode)
	_pause.set_pressed_no_signal(sim.paused)
	_steps.value = sim.steps_per_frame
	_steps_label.text = "Ticks per frame: %d (+/-)" % sim.steps_per_frame
	_fields.set_pressed_no_signal(sim.show_fields)
	_pop.set_value_no_signal(sim.initial_pop)
	for i in _world.item_count:
		if _world.get_item_metadata(i) == sim.world_size:
			_world.select(i)


func _on_rebuild() -> void:
	sim.world_size = _world.get_item_metadata(_world.selected)
	Launch.world_size = sim.world_size
	sim.build()
	sync_from_sim()
	rebuild_requested.emit()


func _section(box: VBoxContainer, text: String) -> void:
	box.add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	box.add_child(l)


func _row(box: VBoxContainer, text: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = text
	l.custom_minimum_size.x = 100
	hb.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(control)
	box.add_child(hb)


func _slider(box: VBoxContainer, key: String, text: String, lo: float, hi: float, step: float) -> void:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", 12)
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = sim.params[key]
	l.text = "%s: %s" % [text, str(sim.params[key])]
	s.value_changed.connect(func(v: float) -> void:
		sim.params[key] = v
		l.text = "%s: %s" % [text, str(snappedf(v, step))])
	box.add_child(s)


func _on_stats(s: Dictionary) -> void:
	var a: Dictionary = s.actions
	_stats_label.text = "\n".join([
		"Tick %d   %.0f ticks/s   %d fps" % [s.tick, s.tps, Engine.get_frames_per_second()],
		"Alive %s   (room %s, grows as needed)" % [_fmt(s.alive), _fmt(s.capacity)],
		"Utility %s   Neural %s" % [_fmt(s.utility), _fmt(s.neural)],
		"Herbivore %s  Omni %s  Carni %s" % [_fmt(s.herbivores), _fmt(s.omnivores), _fmt(s.carnivores)],
		"Births/tick %.0f   Deaths/tick %.0f" % [s.births_per_tick, s.deaths_per_tick],
		"Max generation %d   Species ~%d" % [s.max_generation, s.species],
		"Avg size %.2f speed %.2f diet %.2f" % [s.avg_size, s.avg_speed, s.avg_diet],
		"Avg sense %.2f repro %.1f mut %.3f" % [s.avg_sense, s.avg_repro, s.avg_mutation],
		"Plants %s (+%.0f/-%.0f per tick)" % [_fmt(s.plants), s.plant_births_per_tick, s.plant_deaths_per_tick],
		"  %s" % _forms(s.plant_forms),
		"  growth %.2f defence %.2f fill %.2f seed %.2f" % [s.plant_growth, s.plant_defence, s.plant_biomass, s.seed_size],
		"  flowering %d%% pollinated %d%% fruiting %d%%" % [
				roundi(s.flowering * 100), roundi(s.pollinated * 100), roundi(s.fruiting * 100)],
		"  fruit-dispersed lineages %d%%" % roundi(s.fruit_dispersed * 100),
		"Herbivore detox %.2f   density 1 per %.0f m2" % [s.avg_detox, _area_per_agent(s.alive)],
		"Energy per tick: sun on land %s" % _fmtf(s.sun_on_land),
		"  plants capture %s (%.1f%%), their GPU work %s" % [_fmtf(s.sun_captured),
				100.0 * s.sun_captured / maxf(s.sun_on_land, 1.0), _fmtf(s.plant_compute)],
		"  animals eat %s, spend %s living + %s GPU work" % [_fmtf(s.animal_intake),
				_fmtf(s.animal_upkeep), _fmtf(s.animal_compute)],
		"graze %s hunt %s flee %s flock %s" % [_fmt(a.graze), _fmt(a.hunt), _fmt(a.flee), _fmt(a.flock)],
		"wander %s rest %s scavenge %s hide %s" % [_fmt(a.wander), _fmt(a.rest), _fmt(a.scavenge), _fmt(a.hide)],
		"care %s mark %s home %s recall %s" % [_fmt(a.care), _fmt(a.mark), _fmt(a.home), _fmt(a.recall)],
		"Social: calling %s  hiding %s  displaying %s" % [_fmt(s.calling), _fmt(s.hiding), _fmt(s.displaying)],
		"  young with parent %s  gifts/tick %.0f  marks/tick %.0f" % [_fmt(s.young), s.gifts_per_tick, s.marks_per_tick],
	])
	_graph.push(s)
	_hues.hues = s.hues
	_hues.queue_redraw()


static func _forms(f: Array) -> String:
	var total := maxf(f[0] + f[1] + f[2] + f[3], 1.0)
	return "grass %d%%  flowers %d%%  bushes %d%%  trees %d%%" % [
			roundi(f[0] * 100.0 / total), roundi(f[1] * 100.0 / total),
			roundi(f[2] * 100.0 / total), roundi(f[3] * 100.0 / total)]


func _area_per_agent(alive: int) -> float:
	var side: float = sim.world_size * sim.cell_size
	return side * side * 0.7 / maxf(alive, 1.0) # ~70% of the world is land


static func _fmtf(x: float) -> String:
	return _fmt(roundi(x)) if x >= 100.0 else "%.1f" % x


static func _fmt(n: int) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


class PopGraph extends Control:
	const SERIES := {
		"alive": Color(0.9, 0.9, 0.9),
		"herbivores": Color(0.3, 1.0, 0.4),
		"carnivores": Color(1.0, 0.3, 0.2),
		"utility": Color(0.3, 0.85, 1.0),
		"neural": Color(1.0, 0.35, 0.85),
	}
	var data := {}

	func push(s: Dictionary) -> void:
		for k in SERIES:
			if not data.has(k):
				data[k] = PackedFloat32Array()
			var arr: PackedFloat32Array = data[k]
			arr.append(s[k])
			if arr.size() > HISTORY:
				arr = arr.slice(arr.size() - HISTORY)
			data[k] = arr
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		if not data.has("alive"):
			return
		var top := 1.0
		for v in data["alive"]:
			top = maxf(top, v)
		var y := 12.0
		for k in SERIES:
			var arr: PackedFloat32Array = data[k]
			if arr.size() < 2:
				continue
			var pts := PackedVector2Array()
			for i in arr.size():
				pts.append(Vector2(size.x * i / float(HISTORY - 1), size.y - arr[i] / top * (size.y - 4.0)))
			draw_polyline(pts, SERIES[k], 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(4, y), k, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SERIES[k])
			y += 11.0


class HueBars extends Control:
	var hues := PackedInt32Array()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		if hues.is_empty():
			return
		var top := 1
		for h in hues:
			top = maxi(top, h)
		var w := size.x / hues.size()
		for i in hues.size():
			var hgt := size.y * hues[i] / float(top)
			draw_rect(Rect2(i * w, size.y - hgt, w - 1.0, hgt), Color.from_hsv(i / float(hues.size()), 0.75, 1.0))
