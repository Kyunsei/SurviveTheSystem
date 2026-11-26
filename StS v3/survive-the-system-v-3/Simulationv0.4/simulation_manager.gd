extends Node
class_name SimulationManager

## Same as before: passed to world / alife every tick. 0 = pause.
@export var simulation_speed := 1.0
@export var world: WorldManager
@export var alifemanager: AlifeManager
@export var render_manager: AlifeRendererManager
@export var ui_simulation : CanvasLayer

@export_group("Timestep")
## Fixed simulated time per tick. Same value on every PC = same simulation everywhere.
@export var dt := 0.1
## Ticks per real second, whatever the frame rate.
## Your old code did one tick per frame, so the feel you tuned on a 60 fps
## screen was 60 ticks/s. Keep 60 to keep that feel, but now on every PC.
@export var ticks_per_second := 60.0
## Never more ticks than this in one frame (no "spiral of death" when the PC is slow).
@export var max_ticks_per_frame := 8
## Also stop early if this frame's ticks already took this long (ms).
## 16.6 ms = one 60 fps frame; leave room for rendering.
@export var frame_budget_ms := 12.0
## A frame longer than this (loading, window drag, breakpoint) counts only as this long.
@export var max_frame_delta := 0.25

var running = false
var total_time := 0                 # ticks done since start

## Real seconds the simulation has been running (stops while paused, NOT slowed by
## freezes). Read by species for timers that must last a fixed real time (spider charge).
var real_time := 0.0

var _accum := 0.0                   # ticks owed but not run yet
var interp_alpha := 0.0             # 0..1, between the last tick and the next (for smooth rendering)

## How many ticks the last run (_process call) did: 0 on some frames of a
## fast PC, 1 most of the time, more when catching up on a slow one.
var ticks_this_run := 0

## Ticks actually done per second, measured. Lower than ticks_per_second
## when the PC can't keep up (show it in the UI).
var effective_tps := 0.0
var _speed_ticks := 0
var _speed_time := 0.0

var world_usec := 0.0
var alife_usec := 0.0
var render_usec := 0.0

#----data collected for graph
var graph_data := GraphData.new()
const SAMPLE_INTERVAL := 0.5   # seconds
var _sample_timer := 0.0


func _ready() -> void:
	init()


func init():
	world.init()
	alifemanager.init()
	running = true
	#alifemanager.init_default_species(world,alifemanager)
	DrawSimulation()
	total_time = 0
	_accum = 0.0


func DrawSimulation():
	world.render_world()
	render_manager.init()
	ui_simulation.init()


func _process(delta: float) -> void:
	if running and simulation_speed > 0.0:
		real_time += delta                  # before the clamp: a 1 s freeze counts as 1 s
		delta = minf(delta, max_frame_delta)
		_accum += delta * ticks_per_second

		var budget_usec := frame_budget_ms * 1000.0
		var frame_start := Time.get_ticks_usec()
		var ticks := 0
		world_usec = 0.0
		alife_usec = 0.0

		while _accum >= 1.0 and ticks < max_ticks_per_frame:
			_tick()
			_accum -= 1.0
			ticks += 1
			if Time.get_ticks_usec() - frame_start > budget_usec:
				break                       # out of time this frame

		# Behind schedule: drop the backlog instead of chasing it.
		# The simulation runs in slow motion, but the game never freezes.
		_accum = minf(_accum, 1.0)
		interp_alpha = _accum
		ticks_this_run = ticks

		_measure_speed(delta, ticks)

		# Nothing moved, so nothing to upload.
		# (If you add interpolation, render every frame instead.)
		if ticks > 0:
			var t := Time.get_ticks_usec()
			render_manager.run_visualisation()
			render_usec = Time.get_ticks_usec() - t

		collect_data(delta)
	else:
		ticks_this_run = 0
		effective_tps = 0.0

	ui_simulation.update()
	ui_simulation.display_performance(alife_usec, world_usec, render_usec)


## One fixed step of the whole simulation.
## Three clocks:
##   tick_time        = 1 / ticks_per_second, the same for EVERY tick: movement, action timers
##   dt * sim_speed   = simulated time: metabolism
##   real_time        = wall clock (above): timers that must last fixed real seconds
## The frame's delta is never passed in: a frame runs 0..n ticks, so it means nothing per tick.
func _tick() -> void:
	var tick_time := 1.0 / ticks_per_second
	var t0 := Time.get_ticks_usec()
	world.run_world_simulation(tick_time, dt, simulation_speed)
	var t1 := Time.get_ticks_usec()
	alifemanager.run_simulation(tick_time, dt, simulation_speed)
	var t2 := Time.get_ticks_usec()
	world_usec += t1 - t0
	alife_usec += t2 - t1
	total_time += 1


func _measure_speed(delta: float, ticks: int) -> void:
	_speed_ticks += ticks
	_speed_time += delta
	if _speed_time >= 0.5:
		effective_tps = _speed_ticks / _speed_time
		_speed_ticks = 0
		_speed_time = 0.0

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
