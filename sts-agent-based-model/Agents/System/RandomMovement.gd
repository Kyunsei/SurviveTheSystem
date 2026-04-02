extends AgentSystem
class_name RANDOM_MOVE_SYSTEM

@export var speed: float = 100

func update(manager,delta):
	for i in range(manager.positions.size()):
		var rand = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))
		manager.positions[i] += rand * speed * delta
