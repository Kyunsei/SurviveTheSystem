extends Control


var graph_size = Vector2(10,10)
var data = [10., 25., 15., 30., 20.]
var color_list = [Color(0.0, 0.345, 0.0, 1.0),
Color(0.507, 0.207, 0.164, 1.0),
Color(0.0, 0.117, 1.0, 1.0),
Color(0.635, 0.635, 0.635, 1.0),
Color(0.638, 0.398, 0.895, 1.0),
Color(0.976, 0.11, 0.0, 1.0),
Color(0.826, 0.826, 0.826, 1.0),
Color(0.578, 0.193, 0.246, 1.0),
Color(0.0, 0.722, 0.867, 1.0),
Color(0.566, 0.554, 0.022, 1.0)
]

func _ready() -> void:
	graph_size = $Graph_population.size

func _process(_delta: float) -> void:
	if multiplayer.is_server():
		queue_redraw()
		update_number()

func update_number():
	$Label.text = ""
	#print(GlobalSimulationParameter.life_numbers)
	for n in GlobalSimulationParameter.life_numbers:
		$Label.text += "[color=%s]%s: %s[/color]\n" % [color_list[n].to_html(),AlifeRegistry.SPECIES_ID.keys()[n],GlobalSimulationParameter.life_numbers[n][-1]]



func draw_population():
	var points = []

	var width = graph_size.x
	var height = graph_size.y
	var count = 0
	for n in GlobalSimulationParameter.life_numbers.values():
		points = []
		var max_value = n.max()
		for i in range(n.size()):
				var x = (i / float(n.size() - 1)) * width
				var y = height - (float(n[i]) / max_value) * height
				points.append(Vector2(x, y))
			# Draw lines between points
		for i in range(points.size() - 1):
			draw_line(points[i], points[i + 1],color_list[count], 2.0)
		count += 1
				
	'var max_value = GlobalSimulationParameter.sheep_number_data.max()
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
		draw_line(points3[i], points3[i + 1], Color(0.191, 0.536, 0.551, 1.0), 2.0)'

func _draw():
	draw_population()
