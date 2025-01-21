extends Node2D

@export var num_nodes: int = 10
@export var connectivity: float = 0.5 # Probability of edges (0 to 1)
@export var weighted_edges: bool = true
@export var weight_range: Vector2 = Vector2(1, 10)
@export var iterations: int = 100 # Iterations for force-directed layout
@export var center_position: Vector2 = Vector2(400, 300)
@export var area_size: float = 600.0 # Size of the layout area

var graph: Dictionary = {}
var node_positions: Dictionary = {}

func _ready():
	generate_random_graph()
	calculate_positions()
	visualize_graph()

# Generate a random graph with given properties
func generate_random_graph():
	graph.clear()
	for i in range(num_nodes):
		graph[i] = {}
		for j in range(num_nodes):
			if i != j and randf() < connectivity:
				var weight = randi_range(weight_range.x, weight_range.y) if weighted_edges else 1
				graph[i][j] = weight

# Calculate node positions to minimize crossings
func calculate_positions():
	# Initialize random positions for nodes
	for i in range(num_nodes):
		node_positions[i] = center_position + Vector2(randf() * area_size - area_size / 2, randf() * area_size - area_size / 2)
	
	# Apply force-directed layout
	for o in range(iterations):
		var forces = {}
		for i in range(num_nodes):
			forces[i] = Vector2(0, 0)
		
		for i in range(num_nodes):
			for j in range(num_nodes):
				if i == j: continue
				var direction = (node_positions[i] - node_positions[j]).normalized()
				var distance = max((node_positions[i] - node_positions[j]).length(), 1)
				
				# Repulsive force between all nodes
				forces[i] += direction * (area_size / (distance ** 2))
				
				# Attractive force for connected nodes
				if graph.has(i) and graph[i].has(j):
					forces[i] -= direction * (distance ** 2 / area_size)
		
		# Update positions based on forces
		for i in range(num_nodes):
			node_positions[i] += forces[i] * 0.1
			node_positions[i] = clamp_position(node_positions[i])

# Ensure nodes stay within the layout area
func clamp_position(position: Vector2) -> Vector2:
	return position.clamp(center_position - Vector2(area_size / 2, area_size / 2), center_position + Vector2(area_size / 2, area_size / 2))

# Visualize the graph as nodes and edges
func visualize_graph():
	# Clear previous children
	for child in $NodeContainer.get_children():
		child.queue_free()

	for i in range(num_nodes):
		var position = node_positions[i]
		var node_label = create_node_label(i, position)
		$NodeContainer.add_child(node_label)

	for from_node in graph.keys():
		for to_node in graph[from_node].keys():
			create_edge(node_positions[from_node], node_positions[to_node], graph[from_node][to_node])

# Create a visual node
func create_node_label(index: int, position: Vector2) :
	var label = Label.new()
	label.text = str(index)
	label.position = position - Vector2(10, 10)
	return label

# Create an edge line with optional weight
func create_edge(start: Vector2, end: Vector2, weight: int):
	var edge = Line2D.new()
	edge.default_color = Color(0, 1, 0)
	edge.width = 2
	edge.points = [start, end]
	$NodeContainer.add_child(edge)

	if weighted_edges:
		var weight_label = Label.new()
		weight_label.text = str(weight)
		weight_label.position = (start + end) / 2
		$NodeContainer.add_child(weight_label)
