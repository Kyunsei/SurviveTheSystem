extends Node2D
## 2D view of the unified-life simulation (Launch.get_life()): whole world,
## camera, side panel. Reads --steps, --bench=SECONDS (prints stats, saves a
## screenshot, quits).

const LifeUI := preload("res://scripts/life/life_ui.gd")

var sim: Node
var view: Sprite2D
var cam: Camera2D
var ui: CanvasLayer

var _dragging := false
var _bench_seconds := 0.0
var _bench_elapsed := 0.0
var _stop_tick := 0


func _ready() -> void:
	sim = Launch.get_life()
	sim.active = true
	if Launch.sim != null: # the other simulation waits while this one runs
		Launch.sim.set_meta("was_paused", Launch.sim.paused)
		Launch.sim.paused = true
	sim.steps_per_frame = int(Launch.args.get("steps", sim.steps_per_frame))
	_bench_seconds = float(Launch.args.get("bench", 0.0))
	# Experiments: --log=FILE writes a CSV row per stats read, --stop=TICKS quits there.
	if Launch.args.has("log"):
		sim.log_to(Launch.args.log)
	_stop_tick = int(Launch.args.get("stop", 0))

	view = Sprite2D.new()
	view.texture = sim.texture
	view.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(view)
	cam = Camera2D.new()
	add_child(cam)
	cam.make_current()
	ui = LifeUI.new()
	ui.sim = sim
	add_child(ui)
	_fit_view()
	if Launch.focus_m.x >= 0.0: # coming from 3D: centre on where the player was
		cam.position = Launch.focus_m / sim.cell_size - Vector2.ONE * sim.world_size * 0.5
		cam.zoom = Vector2.ONE * 4.0
		Launch.focus_m = Vector2(-1, -1)
	if _bench_seconds > 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		sim.stats_updated.connect(_print_stats)


func _exit_tree() -> void:
	sim.active = false
	if Launch.sim != null:
		Launch.sim.paused = Launch.sim.get_meta("was_paused", false)


func _process(delta: float) -> void:
	if _stop_tick > 0 and sim.tick >= _stop_tick:
		get_tree().quit()
		return
	var pan := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if pan != Vector2.ZERO:
		cam.position += pan * 600.0 * delta / cam.zoom.x
	if _bench_seconds > 0.0:
		_bench_elapsed += delta
		if _bench_elapsed >= _bench_seconds:
			_bench_seconds = 0.0
			var img := get_viewport().get_texture().get_image()
			var path := OS.get_user_data_dir().path_join("life_bench.png")
			img.save_png(path)
			print("screenshot: ", path)
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_at(1.15)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_at(1.0 / 1.15)
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
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
				sim.color_mode = (event as InputEventKey).keycode - KEY_1
			KEY_EQUAL, KEY_KP_ADD: sim.steps_per_frame = mini(sim.steps_per_frame + 1, 32)
			KEY_MINUS, KEY_KP_SUBTRACT: sim.steps_per_frame = maxi(sim.steps_per_frame - 1, 1)
		ui.sync_from_sim()


## Walk the world point in the centre of the screen in 3D.
func switch_to_3d() -> void:
	var cells: Vector2 = cam.get_screen_center_position() + Vector2.ONE * sim.world_size * 0.5
	var w: float = sim.world_size
	Launch.switch_view(Launch.VIEW_LIFE_3D, Vector2(fposmod(cells.x, w), fposmod(cells.y, w)) * sim.cell_size)


func _zoom_at(factor: float) -> void:
	var before := get_global_mouse_position()
	cam.zoom = (cam.zoom * factor).clamp(Vector2.ONE * 0.05, Vector2.ONE * 64.0)
	cam.force_update_scroll()
	cam.position += before - get_global_mouse_position()


func _fit_view() -> void:
	var vp := get_viewport_rect().size
	var z := minf(vp.x - 420.0, vp.y) / float(sim.world_size)
	cam.zoom = Vector2.ONE * z
	cam.position = Vector2(210.0 / z, 0.0)


func _print_stats(s: Dictionary) -> void:
	var g: Array = s.gained
	var lo: Array = s.lost
	print("tick=%d tps=%.0f organisms=%d sessile=%d (leaves %d, mouth %d, traps %d, forms %s) mobile=%d (plants %d, meat %d, mouthless %d, leaves %d, eyes %d, brains %d/%.1fn) gen=%d births/t=%.0f deaths/t=%.0f" % [
		s.tick, s.tps, s.organisms, s.sessile, s.sessile_leaves, s.sessile_mouth, s.sessile_traps, s.sessile_forms,
		s.mobile, s.mobile_plant_eaters, s.mobile_carnivores, s.mobile_mouthless, s.mobile_with_leaves,
		s.with_eyes, s.with_brain, s.avg_neurons, s.max_generation, s.births_per_tick, s.deaths_per_tick])
	print("   body: settled/t %.2f uprooted/t %.2f life-cycle mobile %d sessile %d | sessile creeping %d muscular %d axis %.2f radial %.2f | mobile anchor %.2f axis %.2f radial %.2f segs %.1f upright %d" % [
		s.settled_per_tick, s.uprooted_per_tick, s.mobile_life_cycle, s.sessile_life_cycle, s.sessile_creepers, s.sessile_muscular,
		s.sessile_axis, s.sessile_radial, s.mobile_anchor, s.mobile_axis, s.mobile_radial, s.mobile_segments, s.mobile_upright])
	print("   organs +/- per 1k ticks: legs %.1f/%.1f brain %.1f/%.1f mouth %.1f/%.1f leaves %.1f/%.1f | energy: sun %.0f cap %.0f s_upk %.0f s_gpu %.1f | m_eat %.1f m_upk %.1f m_gpu %.1f | hwm %d legs %d brains %d" % [
		g[0] * 1000, lo[0] * 1000, g[1] * 1000, lo[1] * 1000, g[2] * 1000, lo[2] * 1000, g[3] * 1000, lo[3] * 1000,
		s.sun_on_land, s.sun_captured, s.sessile_upkeep, s.sessile_compute, s.mobile_intake, s.mobile_upkeep, s.mobile_compute,
		s.organism_hwm, s.leg_hwm, s.brain_hwm])
