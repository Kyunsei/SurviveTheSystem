extends Node

var current_state: State
var states : Dictionary = {}

var initialised: bool = false

@export var initial_state : State 
# Called when the node enters the scene tree for the first time.
func _ready():
	set_physics_process(false)
	set_process(false)

func Activate():
	set_physics_process(true)
	set_process(true)
	
	if not initialised:
		for child in get_children():
			if child is State:
				states[child.name.to_lower()] = child
				child.Transitioned.connect(on_child_transition)
		initialised = true
		
	if initial_state:
		initial_state.Enter()
		current_state = initial_state

func Desactivate():
	get_parent().velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if current_state:
		current_state.Update(delta)


func _physics_process(delta):
	if current_state:
		current_state.Physics_Update(delta)


func on_child_transition(state, new_state_name):
	if state != current_state:
		return
	
	var new_state = states.get(new_state_name.to_lower())
	if !new_state:
		return
		
	if current_state:
		current_state.Exit()
	
	new_state.Enter()
	
	current_state = new_state
