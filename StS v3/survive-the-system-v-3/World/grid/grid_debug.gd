extends Node3D


var voxel_size :Vector3
var isShowing = false
var space_btw_voxel = 0.05
var mm : MultiMesh
var World_size: Vector3
var World : Node3D

func _ready() -> void:
	mm = $MultiMeshInstance3D.multimesh
	World_size = get_parent().World_Size
	World =  get_parent()


func showorhide():
	if isShowing != get_parent().light_grid_visible:
		if get_parent().light_grid_visible:
			$MultiMeshInstance3D.show()
			isShowing = get_parent().light_grid_visible
		else:
			$MultiMeshInstance3D.hide()
			isShowing = get_parent().light_grid_visible
	

func _process(delta: float) -> void:
	showorhide()
	if get_parent().light_grid_visible:
		request_light_grid.rpc_id(1,multiplayer.get_unique_id())

		
		

func update(voxel_size,array):
	#$MultiMeshInstance3D.show()
	var box = BoxMesh.new()
	box.size = voxel_size
	box.size.x -= space_btw_voxel
	box.size.z -= space_btw_voxel
	box.size.y -= space_btw_voxel
	

	mm.mesh = box   # ← VERY IMPORTANT
	


	#multimesh.transform_format = MultiMesh.TRANSFORM_3D
	#multimesh.color_format = MultiMesh.COLOR_8BIT 
	# Then resize (otherwise, changing the format is not allowed).
	mm.instance_count = array.size()#World_size.x * World_size.y * World_size.z
	# Maybe not all of them should be visible at first.
	mm.visible_instance_count = array.size()#World_size.x * World_size.y * World_size.z

	# Set the transform of the instances.
	for i in World_size.x:
		for j in World_size.y:
			for k in World_size.z:
				var index = i + j * World_size.x + k * World_size.x * World_size.y
				var pos = Vector3(i +0.5 -World_size.x/2 , j+0.5 , k + 0.5-World_size.z/2) #$size
				mm.set_instance_transform(index, Transform3D(Basis(), pos))
				var col = Color()
				col.r = array[index]
				mm.set_instance_color(index, col)



				

@rpc("any_peer","call_remote")
func ask_server(peer_id):
	print(peer_id)
	print(multiplayer.get_unique_id())

@rpc("any_peer","call_remote")
func request_light_grid(peer_id):
	var voxel_size = World.light_tile_size
	var array = World.light_array
	send_light_grid.rpc_id(peer_id, voxel_size, array)

@rpc("any_peer","call_remote")
func send_light_grid( voxel_size, array):
	update(voxel_size,array)

	
