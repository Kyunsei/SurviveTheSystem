extends Node

@export var simulation_menu : Node
@export var agent_manager : AgentManager
@export var world_manager : WorldManager

@export var multimesh : Node #MultiMeshInstance3D



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if simulation_menu:
		simulation_menu.agent_manager = agent_manager

	world_manager.init()
	agent_manager.init(world_manager)

	
	
func Load_Simulation():
	pass
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	agent_manager.update(delta)
	multimesh.draw_all(agent_manager.positions_x,agent_manager.positions_y,agent_manager.positions_z, agent_manager.active, agent_manager.agent_count)
	
