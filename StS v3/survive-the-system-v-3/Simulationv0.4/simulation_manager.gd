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


func _update_fps() -> void:
	_fps_label.visible = show_fps
	if not show_fps:
		return
	var fps := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS   ·   alife %.1f ms   ·   tick %d" % [
			fps, alife_usec / 1000.0, total_time]
	# Green at 55+, orange from 25, red below
	var c := Color(1.0, 0.35, 0.3)
	if fps >= 55:
		c = Color(0.55, 1.0, 0.55)
	elif fps >= 25:
		c = Color(1.0, 0.8, 0.35)
	_fps_label.add_theme_color_override("font_color", c)
