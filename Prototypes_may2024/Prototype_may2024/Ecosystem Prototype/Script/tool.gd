extends Node2D

var isInInventory = false

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func Action(actor, interact_array):
	for i in interact_array:
			if i.has_method("Eat"):
				if i.parameters.force < 1 and actor.tool_equiped != null : 
					i.killed()
					
