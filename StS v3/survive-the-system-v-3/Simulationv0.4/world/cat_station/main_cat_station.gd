extends SimulationManager

## One simulation tick per frame. Limit the frame rate in
## Project Settings > Application > Run > Max FPS (e.g. 60), so a fast PC doesn't
## run the simulation faster.

@export var playercontrol :PlayerController

func _ready() -> void:
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
	playercontrol.spawn_and_control("CATRONAUTE", Vector3(50,50,60))


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
