extends Node
class_name SimulationManager

@export var simulation_speed = 1.0
@export var world: WorldManager
@export var alifemanager: AlifeManager
@export var render_manager: AlifeRendererManager
@export var ui_simulation : CanvasLayer
var running = false
var total_time := 0
var dt := 0.1


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
	#$Visual.init($World,$AlifeManager)
	#$simulation_UI/PopTracker.init($AlifeManager)
	running = true
	DrawSimulation()
	total_time = 0

	

func DrawSimulation():
	world.render_world()
	render_manager.init()
	ui_simulation.init()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if running :

		#var dt :float= delta * simulation_speed
		var t0 := Time.get_ticks_usec()
		if simulation_speed > 0:
			 
			world.run_world_simulation(dt, simulation_speed)
			var t1 := Time.get_ticks_usec()
			alifemanager.run_simulation(dt, simulation_speed)
			var t2 := Time.get_ticks_usec()
			render_manager.run_visualisation()
			var t3 := Time.get_ticks_usec()
			
			world_usec = t1 - t0
			alife_usec = t2-t1
			render_usec = t3-t2
			total_time += 1
			collect_data(delta)
			
	ui_simulation.update()
	ui_simulation.display_performance(alife_usec,world_usec,render_usec)
			

func set_simulation_speed(newvalue:float):
	simulation_speed = maxf(newvalue,0.0)
	


func collect_data(delta:float) -> void:
	_sample_timer += delta
	if _sample_timer < SAMPLE_INTERVAL:
		return
	_sample_timer -= SAMPLE_INTERVAL
	var sample := {
		"Time": total_time,
		"Total_entity": alifemanager.global_entity_count,
	}
	for sp in alifemanager.species_array:
		sample[sp.species_name] = sp.active_entity_count
		#var id = str("total entity " + sp.species_name )
		#sample[id] = sp.entity_count
	graph_data.add_sample(sample)
