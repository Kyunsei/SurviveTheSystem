extends Control

const LifeSim := preload("res://scripts/life/life_sim.gd")
## Launcher: shared world settings and a choice between the 2D overview and the
## 3D explorer. Both views return here with Esc, and Tab switches between them.
## The simulation keeps running in the background; opening a view continues it
## unless the settings here were changed, which starts a new world.

var _status: Label
var _buttons: Array[Button] = []
var _evolve_panel: Control
var _evolve_label: Label
var _evolve_bar: ProgressBar
var _evolve_scene := ""
var _evolve_target := 0
var _evolve_start_msec := 0


func _ready() -> void:
	if not Launch.auto_started:
		Launch.auto_started = true
		var view: String = Launch.args.get("view", "2d" if Launch.args.has("bench") else "")
		if view == "2d" or view == "3d":
			Launch.go(Launch.VIEW_3D if view == "3d" else Launch.VIEW_2D)
			return
		if view == "life" or view == "life3d":
			Launch.go(Launch.VIEW_LIFE_3D if view == "life3d" else Launch.VIEW_LIFE)
			return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Launch.sim != null:
		Launch.sim.set_view(false)
	Launch.focus_m = Vector2(-1, -1)
	_build()
	if Launch.args.get("view", "") == "menu" and Launch.args.has("bench"):
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir().path_join("menu.png"))
		get_tree().quit()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.06, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size.x = 760
	center.add_child(col)

	var title := Label.new()
	title.text = "Claude ABM"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Label.new()
	sub.text = "An evolving GPU ecosystem of up to a million agents"
	sub.modulate = Color(1, 1, 1, 0.65)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)

	# Shared world settings.
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)

	var mode := OptionButton.new()
	for m in ["Utility AI", "Neural network", "Mixed (compete)"]:
		mode.add_item(m)
	mode.select(Launch.brain_mode)
	mode.item_selected.connect(func(i: int) -> void: Launch.brain_mode = i)
	_field(grid, "Brains", mode)

	var size_label := Label.new()
	var update_size := func() -> void:
		size_label.text = "World: %.1f km across (%d x %d patches of %d m)" % [
				Launch.world_size * Launch.cell_size / 1000.0, Launch.world_size, Launch.world_size, int(Launch.cell_size)]
	var world := OptionButton.new()
	for s in [512, 1024, 2048, 4096]:
		world.add_item("%d cells" % s)
		world.set_item_metadata(world.item_count - 1, s)
		if s == Launch.world_size:
			world.select(world.item_count - 1)
	world.item_selected.connect(func(i: int) -> void:
		Launch.world_size = world.get_item_metadata(i)
		update_size.call())
	_field(grid, "Grid", world)

	var cell := OptionButton.new()
	for m in [1, 2, 4, 8, 16]:
		cell.add_item("%d m per cell" % m)
		cell.set_item_metadata(cell.item_count - 1, float(m))
		if is_equal_approx(m, Launch.cell_size):
			cell.select(cell.item_count - 1)
	cell.item_selected.connect(func(i: int) -> void:
		Launch.cell_size = cell.get_item_metadata(i)
		update_size.call())
	_field(grid, "Scale", cell)

	var pop := _spin(Launch.initial_pop, 10_000, 4_000_000, 10_000)
	pop.value_changed.connect(func(v: float) -> void: Launch.initial_pop = int(v))
	_field(grid, "Start population", pop)

	var sun := _spin(Launch.param_overrides.get("sun_energy", 0.001) * 10000.0, 1, 60, 1)
	sun.value_changed.connect(func(v: float) -> void:
		Launch.param_overrides["sun_energy"] = v / 10000.0
		if Launch.sim != null:
			Launch.sim.params.sun_energy = v / 10000.0)
	_field(grid, "Sun (x0.0001 /m2/tick)", sun)

	var seed_box := _spin(Launch.seed_value, 1, 99999, 1)
	seed_box.value_changed.connect(func(v: float) -> void: Launch.seed_value = int(v))
	_field(grid, "World seed", seed_box)

	var evolve := OptionButton.new()
	for t in [0, 2000, 5000, 10000, 20000]:
		evolve.add_item("no, start from founders" if t == 0 else "%d ticks first" % t)
		evolve.set_item_metadata(evolve.item_count - 1, t)
		if t == Launch.pre_evolve:
			evolve.select(evolve.item_count - 1)
	evolve.item_selected.connect(func(i: int) -> void: Launch.pre_evolve = evolve.get_item_metadata(i))
	_field(grid, "Pre-evolve", evolve)

	update_size.call()
	size_label.modulate = Color(1, 1, 1, 0.65)
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(size_label)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
	col.add_child(_status)

	# The two views.
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 18)
	col.add_child(cards)
	_card(cards, "2D Overview", "The whole world from above: every agent as a pixel, population graphs, species histogram and live ecology sliders.", Launch.VIEW_2D)
	_card(cards, "3D Explorer", "Walk the same world in first or third person. Watch creatures up close, scare them, lure them, feed or hunt them, breed your favourites, or follow one around.", Launch.VIEW_3D)

	_life_card(col)

	_saved_worlds(col)

	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size.x = 160
	quit.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	quit.pressed.connect(func() -> void: get_tree().quit())
	col.add_child(quit)


## The experimental unified-life simulation (separate world, own view).
func _life_card(col: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.13, 0.11)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	col.add_child(panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	panel.add_child(hb)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(text)
	var t := Label.new()
	t.text = "Unified Life (experimental)"
	t.add_theme_font_size_override("font_size", 20)
	text.add_child(t)
	var d := Label.new()
	d.text = "A separate world with one kind of organism: leaves, legs, eyes, brains and mouths evolve, appear and disappear. Plants and animals have to emerge. Uses the grid, scale and seed above."
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size.x = 420
	d.modulate = Color(1, 1, 1, 0.75)
	text.add_child(d)
	var buttons := VBoxContainer.new()
	hb.add_child(buttons)
	if Launch.life != null:
		var cont := HBoxContainer.new()
		for v in [["Continue in 2D", Launch.VIEW_LIFE], ["in 3D", Launch.VIEW_LIFE_3D]]:
			var c := Button.new()
			c.text = v[0]
			var scene: String = v[1]
			c.pressed.connect(func() -> void: Launch.go(scene))
			cont.add_child(c)
		buttons.add_child(cont)
	for m in [["Primordial world", LifeSim.Start.PRIMORDIAL], ["Seeded world", LifeSim.Start.SEEDED]]:
		var b := Button.new()
		b.text = ("New " + m[0].to_lower()) if Launch.life != null else m[0]
		b.custom_minimum_size.x = 200
		var mode: int = m[1]
		b.pressed.connect(func() -> void:
			if Launch.life == null:
				Launch.args["life"] = "seeded" if mode == LifeSim.Start.SEEDED else "primordial"
				Launch.get_life()
			else:
				Launch.life.world_size = Launch.world_size
				Launch.life.cell_size = Launch.cell_size
				Launch.life.seed_value = Launch.seed_value
				Launch.life.restart(mode)
			Launch.go(Launch.VIEW_LIFE))
		buttons.add_child(b)


func _field(grid: GridContainer, text: String, control: Control) -> void:
	var l := Label.new()
	l.text = text
	grid.add_child(l)
	control.custom_minimum_size.x = 200
	grid.add_child(control)


func _spin(value: int, lo: int, hi: int, step: int) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = value
	return s


func _card(parent: Control, title: String, text: String, scene: String) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.12, 0.15)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 24)
	box.add_child(t)
	var d := Label.new()
	d.text = text
	d.autowrap_mode = TextServer.AUTOWRAP_WORD
	d.custom_minimum_size = Vector2(300, 90)
	d.modulate = Color(1, 1, 1, 0.75)
	box.add_child(d)
	var b := Button.new()
	b.set_meta("title", title)
	b.custom_minimum_size.y = 44
	b.pressed.connect(func() -> void:
		var fresh := Launch.sim == null or Launch.settings_changed()
		if Launch.sim == null:
			Launch.get_sim()
		elif Launch.settings_changed():
			Launch.restart()
		if fresh and Launch.pre_evolve > 0:
			_start_evolving(scene)
		else:
			Launch.go(scene))
	box.add_child(b)
	_buttons.append(b)


## Saved worlds with buttons to load them into either view.
func _saved_worlds(col: VBoxContainer) -> void:
	var worlds := Launch.saved_worlds()
	if worlds.is_empty():
		return
	var title := Label.new()
	title.text = "Saved worlds"
	title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	col.add_child(title)
	for w in worlds.slice(0, 6):
		var h: Dictionary = w.header
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s   tick %d, %d animals, %d plants, %.1f km" % [str(h.time).replace("T", " "), h.tick, h.alive, h.get("plants", 0), h.world * h.cell / 1000.0]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for v in [["2D", Launch.VIEW_2D], ["3D", Launch.VIEW_3D]]:
			var b := Button.new()
			b.text = "Load in " + v[0]
			b.pressed.connect(func() -> void:
				if Launch.load_world(w.path):
					Launch.go(v[1]))
			row.add_child(b)
		col.add_child(row)


## Fast-forward a new world before opening the view.
func _start_evolving(scene: String) -> void:
	_evolve_scene = scene
	_evolve_target = Launch.pre_evolve
	_evolve_start_msec = Time.get_ticks_msec()
	Launch.sim.steps_per_frame = 32
	_evolve_panel = ColorRect.new()
	(_evolve_panel as ColorRect).color = Color(0.03, 0.04, 0.06, 0.94)
	_evolve_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_evolve_panel)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_evolve_panel.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 520
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)
	_evolve_label = Label.new()
	_evolve_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_evolve_label)
	_evolve_bar = ProgressBar.new()
	_evolve_bar.max_value = _evolve_target
	_evolve_bar.custom_minimum_size.y = 24
	box.add_child(_evolve_bar)
	var skip := Button.new()
	skip.text = "Stop here and open the world"
	skip.pressed.connect(func() -> void: _evolve_target = 0)
	box.add_child(skip)


func _process(_delta: float) -> void:
	if _evolve_scene != "":
		var t: int = Launch.sim.tick
		var secs := (Time.get_ticks_msec() - _evolve_start_msec) / 1000.0
		var tps := t / maxf(secs, 0.01)
		_evolve_bar.value = t
		_evolve_label.text = "Evolving the world: tick %d / %d  (%.0f ticks/s, %d s left)
%s agents alive" % [
				t, _evolve_target, tps, int(maxf(_evolve_target - t, 0) / maxf(tps, 1.0)), str(Launch.sim.get_meta("alive", "?"))]
		if t >= _evolve_target:
			Launch.sim.steps_per_frame = 1
			var scene := _evolve_scene
			_evolve_scene = ""
			Launch.go(scene)
		return
	if _status == null:
		return
	var running := Launch.sim != null
	var changed := Launch.settings_changed()
	if not running:
		_status.text = ""
	elif changed:
		_status.text = "Settings changed: opening a view starts a new world"
	else:
		_status.text = "World running in the background: tick %d. Opening a view continues it." % Launch.sim.tick
	for b in _buttons:
		var verb := "Continue in " if running and not changed else "Open "
		b.text = verb + str(b.get_meta("title"))
