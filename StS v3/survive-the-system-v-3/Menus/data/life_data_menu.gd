extends Control


var graph_size = Vector2(10,10)
var data = [10., 25., 15., 30., 20.]
#var points = []

func _ready() -> void:
	graph_size = $Graph_population.size

func _process(delta: float) -> void:
	if multiplayer.is_server():
		queue_redraw()

func draw_population():
	var points1 = []
	var points2 = []
	var points3 = []

	var width = graph_size.x
	var height = graph_size.y
	var max_value = GlobalSimulationParameter.sheep_number_data.max()
	for i in range(GlobalSimulationParameter.sheep_number_data.size()):
		var x = (i / float(GlobalSimulationParameter.sheep_number_data.size() - 1)) * width
		var y = height - (float(GlobalSimulationParameter.sheep_number_data[i]) / max_value) * height
		points1.append(Vector2(x, y))
	# Draw lines between points
	for i in range(points1.size() - 1):
		draw_line(points1[i], points1[i + 1], Color(0.591, 0.4, 0.21, 1.0), 2.0)
	
	max_value = GlobalSimulationParameter.grass_number_data.max()
	for i in range(GlobalSimulationParameter.grass_number_data.size()):
		var x = (i / float(GlobalSimulationParameter.grass_number_data.size() - 1)) * width
		var y = height - (float(GlobalSimulationParameter.grass_number_data[i]) / max_value) * height
		points2.append(Vector2(x, y))
	# Draw lines between points
	for i in range(points2.size() - 1):
		draw_line(points2[i], points2[i + 1], Color(0.218, 0.478, 0.266, 1.0), 2.0)


	max_value = GlobalSimulationParameter.tree_number_data.max()
	for i in range(GlobalSimulationParameter.tree_number_data.size()):
		var x = (i / float(GlobalSimulationParameter.tree_number_data.size() - 1)) * width
		var y = height - (float(GlobalSimulationParameter.tree_number_data[i]) / max_value) * height
		points3.append(Vector2(x, y))
	# Draw lines between points
	for i in range(points3.size() - 1):
		draw_line(points3[i], points3[i + 1], Color(0.191, 0.536, 0.551, 1.0), 2.0)

func _draw():
	draw_population()
