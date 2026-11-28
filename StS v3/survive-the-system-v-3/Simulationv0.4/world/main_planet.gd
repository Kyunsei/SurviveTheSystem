extends SimulationManager

## One simulation tick per frame. Limit the frame rate in
## Project Settings > Application > Run > Max FPS (e.g. 60), so a fast PC doesn't
## run the simulation faster.



func init():
	world.init()
	alifemanager.init()
	running = true
	alifemanager.init_default_species(world,alifemanager)
	DrawSimulation()
	total_time = 0
	is_ready = true
	simulation_ready.emit()
	await get_tree().create_timer(4).timeout
	var pos := world.size/2
	playercontrol.spawn_and_control("CATRONAUTE", Vector3(50,50,60))
