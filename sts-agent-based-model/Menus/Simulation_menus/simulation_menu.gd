extends CanvasLayer

#var agent_number : int
var agent_manager : AgentManager


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.
	


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Panel/FPS.text = "FPS: " +  str(Engine.get_frames_per_second()) 


func _on_line_edit_agentnumber_text_submitted(new_text: String) -> void:
	var agent_number = int(new_text)
	change_agent_number(agent_number)
	
func change_agent_number(agent_number):
	print( agent_manager.agent_count)
	if agent_manager.agent_count < agent_number:
		var diff = agent_number - agent_manager.agent_count
		for d in range(diff):
			agent_manager.Add_Agent()
	
