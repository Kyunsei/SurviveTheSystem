extends Control


var graph_size = Vector2(10,10)
var data = [10, 25, 15, 30, 20]
#var points = []

func _ready() -> void:
	graph_size = $Panel.size

func _draw():
	var points = []
	var width = $Panel.size.x
	var height = $Panel.size.y
	var max_value = data.max()
	
	for i in range(data.size()):
		var x = (i / float(data.size() - 1)) * width
		var y = height - (data[i] / max_value) * height
		points.append(Vector2(x, y))
	
	# Draw lines between points
	for i in range(points.size() - 1):
		draw_line(points[i], points[i + 1], Color.GREEN, 2.0)
