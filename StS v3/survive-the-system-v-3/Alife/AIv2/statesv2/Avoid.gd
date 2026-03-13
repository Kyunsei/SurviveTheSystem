extends STATE
class_name AVOID_STATE


func evaluate(_manager,_i):
	return 1.0

func enter():
	print("avoid selected")

func exit():
	pass

func update(_delta):
	pass
