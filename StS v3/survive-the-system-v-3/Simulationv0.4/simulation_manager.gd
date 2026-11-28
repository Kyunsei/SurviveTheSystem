extends Node
class_name SimulationManager

## One simulation tick per frame. Limit the frame rate in
## Project Settings > Application > Run > Max FPS (e.g. 60), so a fast PC doesn't
## run the simulation faster.

## Passed to world / alife every tick. 0 = pause.
@export var simulation_speed := 1.0
@export var world: WorldManager
@export var alifemanager: AlifeManager
@export var render_manager: AlifeRendererManager
@export var ui_simulation : CanvasLayer
@export var playercontrol :PlayerController

@export_group("FPS display")
@export var show_fps := true                # FPS in the bottom left corner
@export var fps_font_size := 14
## Timings per stage and per species, above the FPS (F3 shows / hides it in game).
@export var show_profile := false
@export var profile_toggle_key := KEY_F3
@export var profile_font_size := 12

@export_group("Pipelined tick")
## On: the simulation runs on the worker threads WHILE the main thread renders, and a
## frame never waits for it (smooth FPS even when the world is heavy). Each tick lasts
## as long as it needs; its delta is the real time since the previous one.
## Off: one tick per frame, the frame waits for it (as before).
@export var pipelined_tick := false
## Pipelined: a tick never counts for more than this (s), after a freeze or a slow tick.
@export var max_tick_delta := 0.25
## Pipelined: agents are drawn moving smoothly between two ticks (the renderer blends the
## previous and the newest tick every frame), instead of jumping once per tick.
## Costs nothing on the CPU; agents are shown about one tick late.
@export var interpolate_agents := true

@export_group("Timestep")
## Simulated time per tick (metabolism: dt x simulation_speed).
@export var dt := 0.1
## A frame longer than this (loading, window drag, breakpoint) counts only as this long,
## so nothing jumps forward after a freeze.
@export var max_frame_delta := 0.1

## Emitted once init() is done: world, species and render are ready.
signal simulation_ready

var running = false
var is_ready := false               # true once init() is done (see simulation_ready)
var total_time := 0                 # ticks done since start

## Real seconds the simulation has been running (stops while paused). Read by species
## for timers that must last a fixed real time (spider charge).
var real_time := 0.0

var world_usec := 0.0
var alife_usec := 0.0
var render_usec := 0.0

#----data collected for graph
var graph_data := GraphData.new()
const SAMPLE_INTERVAL := 0.5   # seconds
var _sample_timer := 0.0

var _fps_label := Label.new()
var _profile_panel := PanelContainer.new()
var _profile_label := Label.new()

var _since_tick := 0.0              # pipelined: real time since the last tick was started
var _tick_start_usec := 0
var _last_tick_delta := 0.0


func _ready() -> void:
	_build_fps_label()
	init()


func init():
	world.init()
	alifemanager.init()
	running = true
	#alifemanager.init_default_species(world,alifemanager)
	DrawSimulation()
	total_time = 0
	is_ready = true
	simulation_ready.emit()


func DrawSimulation():
	world.render_world()
	render_manager.init()
	if ui_simulation:
		ui_simulation.init()


func _process(delta: float) -> void:
	alifemanager.pipelined = pipelined_tick
	if render_manager != null:
		render_manager.interpolate = pipelined_tick and interpolate_agents and running
	if pipelined_tick or alifemanager.tick_running():
		_process_pipelined(delta)
		_update_fps()
		if ui_simulation:
			ui_simulation.update()
			ui_simulation.display_performance(alife_usec, world_usec, render_usec)
		return

	# One tick per frame: nodes of "between_ticks" run here, before it
	get_tree().call_group("between_ticks", "between_ticks", delta)
	if running and simulation_speed > 0.0:
		real_time += delta
		#delta = minf(delta, max_frame_delta)

		# One tick
		var t0 := Time.get_ticks_usec()
		world.run_world_simulation(delta, dt, simulation_speed)
		var t1 := Time.get_ticks_usec()
		alifemanager.run_simulation(delta, dt, simulation_speed)
		var t2 := Time.get_ticks_usec()
		render_manager.run_visualisation()
		var t3 := Time.get_ticks_usec()

		world_usec = t1 - t0
		alife_usec = t2 - t1
		render_usec = t3 - t2
		total_time += 1
		collect_data(delta)

	_update_fps()
	if ui_simulation:
		ui_simulation.update()
		ui_simulation.display_performance(alife_usec, world_usec, render_usec)


func set_simulation_speed(newvalue: float):
	simulation_speed = maxf(newvalue, 0.0)


func collect_data(delta: float) -> void:
	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return
	_sample_timer -= SAMPLE_INTERVAL

	var sample := {
		"Time": total_time,
		"Total_entity": alifemanager.global_active_entity_count,
	}
	for sp in alifemanager.species_array:
		sample[sp.species_name] = sp.active_entity_count
	graph_data.add_sample(sample)


# --- FPS display (bottom left) ----------------------------------------------------------

func _build_fps_label() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100                         # above the game UI
	add_child(layer)
	_fps_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT,
			Control.PRESET_MODE_MINSIZE, 8)
	_fps_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps_label.add_theme_font_size_override("font_size", fps_font_size)
	_fps_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	layer.add_child(_fps_label)

	# Profile: a dark box above the FPS line, monospace so the columns line up
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.65)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(6)
	_profile_panel.add_theme_stylebox_override("panel", style)
	_profile_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT,
			Control.PRESET_MODE_MINSIZE, 8)
	_profile_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_profile_panel.offset_bottom = -(fps_font_size + 16)     # just above the FPS line
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "monospace"])
	_profile_label.add_theme_font_override("font", mono)
	_profile_label.add_theme_font_size_override("font_size", profile_font_size)
	_profile_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.92))
	_profile_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_label.text = "profile: waiting for ticks..."
	_profile_panel.add_child(_profile_label)
	layer.add_child(_profile_panel)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo \
			and event.physical_keycode == profile_toggle_key:
		show_profile = not show_profile
		get_viewport().set_input_as_handled()


func _update_fps() -> void:
	alifemanager.collect_profile = show_profile
	_profile_panel.visible = show_profile
	if show_profile and alifemanager.profile_text != "":
		_profile_label.text = alifemanager.profile_text
		_profile_panel.reset_size()
		_profile_panel.position.y = get_viewport().get_visible_rect().size.y \
				- _profile_panel.size.y - fps_font_size - 20
	_fps_label.visible = show_fps
	if not show_fps:
		return
	var fps := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS   ·   alife %.1f ms   ·   tick %d%s" % [
			fps, alife_usec / 1000.0, total_time, "   ·   pipelined" if pipelined_tick else ""]
	# Green at 55+, orange from 25, red below
	var c := Color(1.0, 0.35, 0.3)
	if fps >= 55:
		c = Color(0.55, 1.0, 0.55)
	elif fps >= 25:
		c = Color(1.0, 0.8, 0.35)
	_fps_label.add_theme_color_override("font_color", c)


# --- Pipelined tick -----------------------------------------------------------------------
#
#   frame N:    tick T finished?  no  -> just render (agents stay where tick T-1 left them)
#               tick T finished?  yes -> finish it (spawns, grid, render buffer),
#                                        between_ticks nodes (players' actions, network,
#                                        spawners), world, then START tick T+1 and return
#   The worker threads run tick T+1 while the main thread draws the frame.

func _process_pipelined(delta: float) -> void:
	var sim_on: bool = running and simulation_speed > 0.0
	if sim_on:
		real_time += delta
	_since_tick += delta

	if alifemanager.tick_running():
		if not alifemanager.tick_done():
			return                            # still working: draw the last finished tick
		var t0 := Time.get_ticks_usec()
		alifemanager.finish_tick()
		var t1 := Time.get_ticks_usec()
		render_manager.tick_delta = _last_tick_delta   # stamps this tick for the smooth playback
		render_manager.run_visualisation()
		render_usec = Time.get_ticks_usec() - t1
		alife_usec = t0 - _tick_start_usec + (t1 - t0)   # the whole tick, start to finish
		total_time += 1
		collect_data(_last_tick_delta)

	# Arrays are free: players' actions, network, spawners... then the next tick
	var d := minf(_since_tick, max_tick_delta)
	_since_tick = 0.0
	get_tree().call_group("between_ticks", "between_ticks", d)
	if not sim_on or not pipelined_tick:
		return                                # paused, or just switched back to one tick per frame
	var w0 := Time.get_ticks_usec()
	world.run_world_simulation(d, dt, simulation_speed)
	world_usec = Time.get_ticks_usec() - w0
	_last_tick_delta = d
	_tick_start_usec = Time.get_ticks_usec()
	alifemanager.begin_tick(d, dt, simulation_speed)
