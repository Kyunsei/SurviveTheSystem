extends Node
class_name State

signal Transitioned

func Enter():
	pass
	
func Exit():
	pass
	
func Update(_delta: float):
	pass
	
func Physics_Update(_delta: float):
	pass
	
func compare_by_distance(a, b):
		#a.getCenterPos().distance_to(get_parent().get_parent().getCenterPos())
		return a.getCenterPos().distance_to(get_parent().get_parent().getCenterPos()) < b.getCenterPos().distance_to(get_parent().get_parent().getCenterPos())
