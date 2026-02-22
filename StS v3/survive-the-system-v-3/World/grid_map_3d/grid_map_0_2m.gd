extends GridMap
var width = 1
var height = 1
var depth = 1
@export var tile_id = 0   # The MeshLibrary item ID you want to use

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	width = get_parent().get_parent().World_Size.x/5
	height = get_parent().get_parent().World_Size.y
	depth = get_parent().get_parent().World_Size.z/5
	make_gridmap()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func make_gridmap():
	for x in range(-width/2,width/2):
		for y in range(height):
			for z in range(-depth/2,depth/2):
				set_cell_item(Vector3i(x, y, z), tile_id)
