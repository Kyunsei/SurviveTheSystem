extends Node2D
## The 2D overview of the shared simulation (Launch.get_sim()): world view,
## camera and UI. Tab switches to the 3D explorer at the centre of the view.
## Besides Launch's options this view reads --steps, --bench=SECONDS, --profile=1.

const Simulation := preload("res://scripts/simulation.gd")
const SimUI := preload("res://scripts/ui.gd")

var sim: Node
var view: Sprite2D
var cam: Camera2D
var ui: CanvasLayer

var _dragging := false
var _bench_seconds := 0.0
var _bench_elapsed := 0.0


func _ready() -> void:
	sim = Launch.get_sim()
	sim.set_view(false)
	_apply_cmdline()

	view = Sprite2D.new()
	view.texture = sim.texture
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(view)

	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()

	ui = SimUI.new()
	ui.sim = sim
	add_child(ui)
	ui.rebuild_requested.connect(_on_rebuild)

	_fit_view()
	if Launch.focus_m.x >= 0.0:
		# Coming from 3D: centre on where the player was.
		cam.position = Launch.focus_m / sim.cell_size - Vector2.ONE * sim.world_size * 0.5
		cam.zoom = Vector2.ONE * 4.0
		Launch.focus_m = Vector2(-1, -1)
	if _bench_seconds > 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		sim.stats_updated.connect(_print_stats)


func _apply_cmdline() -> void:
	var args: Dictionary = Launch.args
	sim.steps_per_frame = int(args.get("steps", sim.steps_per_frame))
	sim.profile = args.get("profile", "0") == "1"
	_bench_seconds = float(args.get("bench", 0.0))


func _on_rebuild() -> void:
	view.texture = sim.texture
	_fit_view()


func _process(delta: float) -> void:
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if pan != Vector2.ZERO:
		cam.position += pan * 600.0 * delta / cam.zoom.x
	if _bench_seconds > 0.0:
		_bench_elapsed += delta
		if _bench_elapsed >= _bench_seconds:
			_bench_seconds = 0.0
			var img := get_viewport().get_texture().get_image()
			var path := OS.get_user_data_dir().path_join("bench.png")
			img.save_png(path)
			print("screenshot: ", path)
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.15, mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.15, mb.position)
		elif mb.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_LEFT]:
			_dragging = mb.pressed
	elif event is InputEventMouseMotion and _dragging:
		cam.position -= (event as InputEventMouseMotion).relative / cam.zoom.x
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE: Launch.go(Launch.MENU)
			KEY_TAB: switch_to_3d()
			KEY_SPACE: sim.paused = not sim.paused
			KEY_F: _fit_view()
			KEY_R: sim.reset()
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				sim.color_mode = (event as InputEventKey).keycode - KEY_1
			KEY_EQUAL, KEY_KP_ADD: sim.steps_per_frame = mini(sim.steps_per_frame + 1, 32)
			KEY_MINUS, KEY_KP_SUBTRACT: sim.steps_per_frame = maxi(sim.steps_per_frame - 1, 1)
		ui.sync_from_sim()


## Open the 3D explorer at the world point in the centre of the screen.
func switch_to_3d() -> void:
	var cells: Vector2 = cam.get_screen_center_position() + Vector2.ONE * sim.world_size * 0.5
	var w: float = sim.world_size
	var focus: Vector2 = Vector2(fposmod(cells.x, w), fposmod(cells.y, w)) * sim.cell_size
	Launch.switch_view(Launch.VIEW_3D, focus)


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := get_global_mouse_position()
	cam.zoom = (cam.zoom * factor).clamp(Vector2.ONE * 0.05, Vector2.ONE * 64.0)
	cam.force_update_scroll()
	cam.position += before - get_global_mouse_position()


func _fit_view() -> void:
	var vp := get_viewport_rect().size
	var z := minf(vp.x - 340.0, vp.y) / float(sim.world_size)
	cam.zoom = Vector2.ONE * z
	cam.position = Vector2(170.0 / z, 0.0)


func _print_stats(s: Dictionary) -> void:
	print("hwm=%d tick=%d tps=%.1f fps=%d alive=%d util=%d nn=%d herb=%d omni=%d carn=%d gen=%d species=%d births/t=%.0f deaths/t=%.0f diet=%.2f size=%.2f speed=%.2f energy=%.2f actions=%s" % [
		s.high_water, s.tick, s.tps, Engine.get_frames_per_second(), s.alive, s.utility, s.neural,
		s.herbivores, s.omnivores, s.carnivores, s.max_generation, s.species,
		s.births_per_tick, s.deaths_per_tick, s.avg_diet, s.avg_size, s.avg_speed,
		s.avg_energy, s.actions])
	print("   plants=%d (+%.0f/-%.0f) %s defence=%.2f fill=%.2f flowering=%.2f pollinated=%.2f fruiting=%.2f fruit-disp=%.2f seed=%.2f detox=%.2f  1 animal per %.0f m2" % [
		s.plants, s.plant_births_per_tick, s.plant_deaths_per_tick, SimUI._forms(s.plant_forms), s.plant_defence,
		s.plant_biomass, s.flowering, s.pollinated, s.fruiting, s.fruit_dispersed, s.seed_size, s.avg_detox,
		sim.world_size * sim.cell_size * sim.world_size * sim.cell_size * 0.7 / maxf(s.alive, 1.0)])
	print("   social: calling %d hiding %d displaying %d young-with-parent %d gifts/t %.1f marks/t %.1f | %s" % [
		s.calling, s.hiding, s.displaying, s.young, s.gifts_per_tick, s.marks_per_tick,
		"hide %d care %d mark %d home %d recall %d" % [s.actions.hide, s.actions.care, s.actions.mark, s.actions.home, s.actions.recall]])
	print("   energy/tick: sun=%.0f captured=%.0f plant_gpu=%.1f | animals eat=%.1f upkeep=%.1f gpu=%.1f | room %d / %d" % [
		s.sun_on_land, s.sun_captured, s.plant_compute, s.animal_intake, s.animal_upkeep, s.animal_compute,
		s.capacity, s.plant_capacity])
