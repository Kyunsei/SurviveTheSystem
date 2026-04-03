extends AgentSystem
class_name RANDOM_MOVE_SYSTEM

@export var speed: float = 100

func update(manager,delta):
	var positions = manager.positions
	var positions_x = manager.positions_x
	var positions_y = manager.positions_y
	var positions_z = manager.positions_z
	var active = manager.active
	var spd = speed * delta
	for i in range(manager.positions.size()):
		if active[i]:
			var r = Vector3(
			randf() * 2.0 - 1.0,
			randf() * 2.0 - 1.0,
			randf() * 2.0 - 1.0
			)			
			positions_x[i] += r.x * spd
			positions_y[i] += r.y * spd
			positions_z[i] += r.z * spd
