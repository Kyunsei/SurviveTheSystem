extends Node
class_name State

var life_entity: LifeEntity

signal Transitioned

func Enter():
	pass
	
func Exit():
	pass
	
func Update(_delta: float):
	pass
	
func Physics_Update(_delta: float):
	pass


func getClosestLife(array):
	var closest_entity: LifeEntity = null
	var min_distance: float = INF
	var calc_distance: float = 0
	for p in array:
		calc_distance = life_entity.position.distance_to(p.position)
		if calc_distance <= min_distance:
			min_distance = calc_distance
			closest_entity = p
	return closest_entity

'func compare_by_distance(a, b):
		#a.getCenterPos().distance_to(get_parent().get_parent().getCenterPos())
		return a.getCenterPos().distance_to(get_parent().get_parent().getCenterPos()) < b.getCenterPos().distance_to(get_parent().get_parent().getCenterPos())
'
