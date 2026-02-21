extends Node
class_name StateManager
@export var current_state : State

func _enter_tree() -> void:
	for s in get_children():
		if s is State:
			s.player = get_parent()
			s.state_manager = self
	

func _process(delta: float) -> void:
	if get_parent().isInit:
		if current_state:
			current_state.update(delta)

func _physics_process(delta: float) -> void:
	if get_parent().isInit:
		if current_state:

			current_state.physics_update(delta)




func choose_action():
	if !get_parent().isInit:
		return

	var best_score = 0
	var score 
	var best_action
	for s in get_children():
		if s is State:
			s.player = get_parent()
			score = s.evaluate()
			#print(s.name + " is " + str(score))
			
			if score > best_score:
				best_score = score
				best_action = s
			
			elif score == best_score:
				#print("equal_score")
				if randi() == 1:
					best_action = s
	if best_action:
		if best_action ==current_state:
			return
		get_parent().get_node("debugLabel").text =best_action.name
		if current_state:
			current_state.exit()
		best_action.enter()
		current_state = best_action
