extends Control
class_name Graph

var normalized := false

var data_set: Array[Array] = []
var colors: Array[Color] = [
	Color(0.9, 0.3, 0.3),
	Color(0.3, 0.7, 0.3),
	Color(0.3, 0.5, 0.9),
	Color(0.9, 0.7, 0.2),
	Color(0.6, 0.4, 0.8),
]

func _ready() -> void:
	for n in 5:
		var serie: Array = []
		for i in 300:
			serie.append(i * n)
		data_set.append(serie)
	queue_redraw()

func _draw() -> void:
	# Max global sur toutes les séries
	var max_value := 0.0
	for arr in data_set:
		if not arr.is_empty():
			max_value = max(max_value, float(arr.max()))
	if max_value == 0.0:
		max_value = 1.0  # évite la division par zéro si tout vaut 0

	var width := size.x
	var height := size.y

	for n in data_set.size():
		var arr: Array = data_set[n]
		if arr.size() < 2:
			continue
		
		if normalized:
			max_value = arr.max()
		#print(max_value)

		var points := PackedVector2Array()
		for i in arr.size():
			var x := (i / float(arr.size() - 1)) * width
			var y = height - (arr[i] / max_value) * height
			points.append(Vector2(x, y))
		
		

			
		draw_polyline(points, colors[n % colors.size()], 2.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()
