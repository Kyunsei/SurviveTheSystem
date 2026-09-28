extends CanvasLayer
## Side panel of the unified-life view: statistics, charts and live parameters.

const LifeSim := preload("res://scripts/life/life_sim.gd")
const HISTORY := 400

var sim: Node

var _stats_label: Label
var _graph: Graph
var _color: OptionButton
var _pause: Button
var _steps: HSlider
var _steps_label: Label


func _ready() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -420.0
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
	title.text = "Unified Life"
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "One kind of organism; leaves, legs, eyes, brains and mouths evolve."
	sub.add_theme_font_size_override("font_size", 11)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	sub.modulate = Color(1, 1, 1, 0.6)
	box.add_child(sub)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 12)
	_stats_label.text = "waiting for stats..."
	box.add_child(_stats_label)

	_graph = Graph.new()
	_graph.custom_minimum_size = Vector2(0, 130)
	box.add_child(_graph)

	_section(box, "Run")
	var starts := VBoxContainer.new()
	for m in [["New primordial world", LifeSim.Start.PRIMORDIAL], ["New seeded world", LifeSim.Start.SEEDED]]:
		var b := Button.new()
		b.text = m[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode: int = m[1]
		b.pressed.connect(func() -> void: sim.restart(mode))
		starts.add_child(b)
	box.add_child(starts)
	_pause = Button.new()
	_pause.toggle_mode = true
	_pause.text = "Pause (Space)"
	_pause.toggled.connect(func(on: bool) -> void: sim.paused = on)
	box.add_child(_pause)
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
	for m in LifeSim.COLOR_MODES:
		_color.add_item(m)
	_color.item_selected.connect(func(i: int) -> void: sim.color_mode = i)
	_row(box, "Colour (1-5)", _color)
	var legend := Label.new()
	legend.add_theme_font_size_override("font_size", 11)
	legend.modulate = Color(1, 1, 1, 0.6)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD
	legend.text = "Background: sessile canopy. Dots: mobile organisms, and unusual sessile ones (feeding, leafless, muscular, life cycle). Lifestyle: green = sunlight, yellow = eats plants, red = eats animals, bluish = brain. Body plan: green = rooted upright, teal = creeping, orange = free and muscular, purple tint = radial."
	box.add_child(legend)

	_section(box, "Energy and evolution (live)")
	_slider(box, "sun_energy", "Sun energy /m2", 0.0, 0.004, 0.0001)
	_slider(box, "compute_cost", "Compute cost", 0.0, 0.003, 0.0001)
	_slider(box, "organ_jump", "Organ jumps", 0.0, 0.05, 0.001)
	_slider(box, "mutation_scale", "Mutation scale", 0.0, 5.0, 0.1)
	_slider(box, "metabolism", "Metabolism", 0.0, 0.05, 0.001)
	_slider(box, "plant_efficiency", "Plant efficiency", 0.05, 1.0, 0.05)
	_slider(box, "meat_efficiency", "Meat efficiency", 0.0, 2.0, 0.05)
	_slider(box, "attack_power", "Attack power", 0.0, 3.0, 0.05)
	_slider(box, "vision_cost", "Vision cost", 0.0, 0.02, 0.001)
	_slider(box, "fire_rate", "Fire rate", 0.0, 0.2, 0.005)

	var walk := Button.new()
	walk.text = "Walk here in 3D (Tab)"
	walk.pressed.connect(func() -> void: get_parent().switch_to_3d())
	box.add_child(walk)
	var menu := Button.new()
	menu.text = "Main menu (Esc)"
	menu.pressed.connect(func() -> void: Launch.go(Launch.MENU))
	box.add_child(menu)

	sim.stats_updated.connect(_on_stats)
	sim.restarted.connect(func() -> void: _graph.data.clear())
	sync_from_sim()


func sync_from_sim() -> void:
	_color.select(sim.color_mode)
	_pause.set_pressed_no_signal(sim.paused)
	_steps.value = sim.steps_per_frame
	_steps_label.text = "Ticks per frame: %d (+/-)" % sim.steps_per_frame


func _section(box: VBoxContainer, text: String) -> void:
	box.add_child(HSeparator.new())
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.55, 0.8, 1.0))
	box.add_child(l)


func _row(box: VBoxContainer, label: String, control: Control) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.custom_minimum_size.x = 110
	hb.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(control)
	box.add_child(hb)


func _slider(box: VBoxContainer, key: String, label: String, lo: float, hi: float, step: float) -> void:
	var l := Label.new()
	box.add_child(l)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = sim.params[key]
	var show := func(v: float) -> void: l.text = "%s: %s" % [label, str(snappedf(v, step))]
	show.call(s.value)
	s.value_changed.connect(func(v: float) -> void:
		sim.params[key] = v
		show.call(v))
	box.add_child(s)


func _on_stats(s: Dictionary) -> void:
	var a: Dictionary = s.actions
	var g: Array = s.gained
	var lo: Array = s.lost
	var f: Array = s.sessile_forms
	_stats_label.text = "\n".join([
		"Tick %d   %.0f ticks/s   %d fps   generation %d" % [s.tick, s.tps, Engine.get_frames_per_second(), s.max_generation],
		"Organisms %s" % _fmt(s.organisms),
		"Sessile %s: with leaves %s, without %s" % [_fmt(s.sessile), _fmt(s.sessile_leaves), _fmt(s.sessile_no_leaves)],
		"  with a mouth %s (traps %s)   size %.2f" % [_fmt(s.sessile_mouth), _fmt(s.sessile_traps), s.sessile_size],
		"  heights %s" % _forms(f),
		"  creeping %s, muscular %s, with a life cycle %s" % [_fmt(s.sessile_creepers), _fmt(s.sessile_muscular), _fmt(s.sessile_life_cycle)],
		"Mobile %s: eat plants %s, eat animals %s" % [_fmt(s.mobile), _fmt(s.mobile_plant_eaters), _fmt(s.mobile_carnivores)],
		"  no mouth %s, with leaves %s" % [_fmt(s.mobile_mouthless), _fmt(s.mobile_with_leaves)],
		"  eyes %s, brains %s (%.1f neurons)" % [_fmt(s.with_eyes), _fmt(s.with_brain), s.avg_neurons],
		"  size %.2f speed %.2f sense %.2f carnivory %.2f" % [s.mobile_size, s.mobile_speed, s.mobile_sense, s.mobile_carni],
		"  segments %.1f  radial %.2f  upright %s  anchorage %.2f  life cycle %s" % [s.mobile_segments, s.mobile_radial, _fmt(s.mobile_upright), s.mobile_anchor, _fmt(s.mobile_life_cycle)],
		"Plant <-> animal: settled %.2f, uprooted %.2f per tick (metamorphosis)" % [s.settled_per_tick, s.uprooted_per_tick],
		"Births/tick %.0f (%.0f sexual)   deaths/tick %.0f" % [s.births_per_tick, s.sexual_births_per_tick, s.deaths_per_tick],
		"Lineages: %d sessile, %d mobile   body-plan diversity %.2f" % [s.lineages_sessile, s.lineages_mobile, s.bodyplan_diversity],
		"Guilds: plants %s creepers %s traps %s feeders %s" % [_fmt(s.plants), _fmt(s.creepers), _fmt(s.traps), _fmt(s.sessile_feeders)],
		"  grazers %s predators %s omnivores %s leafy walkers %s" % [_fmt(s.grazers), _fmt(s.predators), _fmt(s.omnivores), _fmt(s.mobile_leafy)],
		"Organs gained / lost per 1000 ticks:",
		"  legs +%.1f -%.1f   brain +%.1f -%.1f" % [g[0] * 1000.0, lo[0] * 1000.0, g[1] * 1000.0, lo[1] * 1000.0],
		"  mouth +%.1f -%.1f   leaves +%.1f -%.1f" % [g[2] * 1000.0, lo[2] * 1000.0, g[3] * 1000.0, lo[3] * 1000.0],
		"Energy per tick: sun on land %s" % _fmtf(s.sun_on_land),
		"  sessile capture %s, upkeep %s, GPU work %s" % [_fmtf(s.sun_captured), _fmtf(s.sessile_upkeep), _fmtf(s.sessile_compute)],
		"  mobile eat %s, upkeep %s, GPU work %s" % [_fmtf(s.mobile_intake), _fmtf(s.mobile_upkeep), _fmtf(s.mobile_compute)],
		"Actions: eat %s hunt %s flee %s bask %s" % [_fmt(a.eat), _fmt(a.hunt), _fmt(a.flee), _fmt(a.bask)],
		"  wander %s rest %s flock %s" % [_fmt(a.wander), _fmt(a.rest), _fmt(a.flock)],
	])
	_graph.push(s)


static func _forms(f: Array) -> String:
	var total := maxf(f[0] + f[1] + f[2] + f[3], 1.0)
	return "<0.5 m %d%%  <2 m %d%%  <6 m %d%%  taller %d%%" % [
		roundi(100.0 * f[0] / total), roundi(100.0 * f[1] / total), roundi(100.0 * f[2] / total), roundi(100.0 * f[3] / total)]


static func _fmtf(x: float) -> String:
	return _fmt(roundi(x)) if x >= 100.0 else "%.1f" % x


static func _fmt(n: int) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


## Population chart: each series is scaled to its own maximum (they differ by
## orders of magnitude), labelled with its latest value.
class Graph extends Control:
	const SERIES := {
		"sessile": Color(0.3, 0.8, 0.3),
		"mobile": Color(0.9, 0.9, 0.9),
		"mobile_plant_eaters": Color(1.0, 0.85, 0.2),
		"mobile_carnivores": Color(1.0, 0.3, 0.2),
		"with_brain": Color(0.4, 0.7, 1.0),
		"sessile_mouth": Color(0.85, 0.4, 0.9),
	}
	var data := {}

	func push(s: Dictionary) -> void:
		for k in SERIES:
			var arr: PackedFloat32Array = data.get(k, PackedFloat32Array())
			arr.append(s[k])
			if arr.size() > HISTORY:
				arr = arr.slice(arr.size() - HISTORY)
			data[k] = arr
		queue_redraw()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
		var y := 12.0
		for k in SERIES:
			if not data.has(k):
				continue
			var arr: PackedFloat32Array = data[k]
			var top := 1.0
			for v in arr:
				top = maxf(top, v)
			if arr.size() >= 2:
				var pts := PackedVector2Array()
				for i in arr.size():
					pts.append(Vector2(size.x * i / float(HISTORY - 1), size.y - arr[i] / top * (size.y - 4.0)))
				draw_polyline(pts, SERIES[k], 1.5)
			draw_string(ThemeDB.fallback_font, Vector2(4, y), "%s %d" % [k.replace("_", " "), int(arr[-1]) if arr.size() > 0 else 0],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 10, SERIES[k])
			y += 11.0
