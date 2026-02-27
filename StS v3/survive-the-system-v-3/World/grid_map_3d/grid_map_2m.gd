extends GridMap
var width = 1
var height = 1
var depth = 1
@export var tile_ids: Array[int] = []  # The MeshLibrary item ID you want to use
@export var placement_density: float = 0.5  # 0 → empty, 1 → full

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	width = get_parent().get_parent().World_Size_with_walls.x
	height = get_parent().get_parent().World_Size.y*2
	depth = get_parent().get_parent().World_Size_with_walls.z
	make_gridmap(6)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func make_gridmap(layers: int):
	randomize()
	
	var outer_half = min(width, depth) / 2
	var inner_half = outer_half * get_parent().get_parent().Wall_size   # Adjust hole size here
	
	for x in range(-width/2, width/2):
		for y in range(layers):
			for z in range(-depth/2, depth/2):
				
				var square_dist = max(abs(x), abs(z))
				
				# Keep only the square ring
				if square_dist <= outer_half and square_dist >= inner_half:
					
					if randf() <= placement_density:
						
						if tile_ids.size() > 0:
							var random_tile = tile_ids[randi() % tile_ids.size()]
							set_cell_item(Vector3i(x, y, z), random_tile)
