extends CanvasLayer

#var agent_number : int
var agent_manager : AgentManager
var world_manager : WorldManager

var selected_world = 0 

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
	if agent_manager.agent_count < agent_number:
		var diff = agent_number - agent_manager.agent_count
		for d in range(diff):
			agent_manager.Add_Agent()
			
	elif agent_manager.agent_count > agent_number:
		var diff = agent_manager.agent_count - agent_number 
		for d in range(diff):
			agent_manager.Remove_Agent(d)
	


func _on_line_edit_z_text_submitted(new_text: String) -> void:
	if world_manager.size_y.size()< selected_world+1:
		return
	world_manager.size_z[selected_world] = float(new_text)


func _on_line_edit_y_text_submitted(new_text: String) -> void:
	if world_manager.size_y.size()< selected_world+1:
		return
	world_manager.size_y[selected_world] = float(new_text)


func _on_line_edit_x_text_submitted(new_text: String) -> void:
	if world_manager.size_y.size() < selected_world+1:
		return
	world_manager.size_x[selected_world] = float(new_text)

func _on_line_edit_id_text_submitted(new_text: String) -> void:
	selected_world = int(new_text)


func _on_check_button_toggled(toggled_on: bool) -> void:
	agent_manager.isthreading = toggled_on
