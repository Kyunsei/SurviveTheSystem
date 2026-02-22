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
	
	var box = BoxMesh.new()
	box.size = World.light_tile_size#voxel_size
	box.size.x -= space_btw_voxel
	box.size.z -= space_btw_voxel
	box.size.y -= space_btw_voxel
	
	mm.mesh = box   # ← VERY IMPORTANT
	var mat = StandardMaterial3D.new()
	#mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	box.material= mat	
	mm.use_colors = true


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
		#request_light_grid.rpc_id(1,multiplayer.get_unique_id())
		request_bin_grid.rpc_id(1,multiplayer.get_unique_id())
		


func update(voxel_size,array):
	var new_size = World_size/voxel_size
	#print(new_size)
	mm.mesh.size = voxel_size
	mm.mesh.size.x -= space_btw_voxel
	mm.mesh.size.z -= space_btw_voxel
	mm.mesh.size.y -= space_btw_voxel
	mm.mesh.size.y = 0.6

	mm.instance_count = array.size()#World_size.x * World_size.y * World_size.z
	# Maybe not all of them should be visible at first.
	mm.visible_instance_count = array.size()#World_size.x * World_size.y * World_size.z	
	# Set the transform of the instances.
	for i in new_size.x:
		for j in new_size.y:
			for k in new_size.z:
				var index = i + j * new_size.x + k * new_size.x * new_size.y
				if index >= array.size():
					return
				var pos = Vector3(i*voxel_size.x +voxel_size.x/2 -World_size.x/2 , j+0.5 , k*voxel_size.z + voxel_size.z/2-World_size.z/2) #$size
				mm.set_instance_transform(index, Transform3D(Basis(), pos))
				var col = Color(0.0, 0.0, 0.0, 1.0)
				col.g = clamp(float(array[index])/25.0,0,1)
				#print(array[index])
				'col.r = array[index]
				col.g = array[index]
				col.b = array[index]
				col.a = 0.5'

				mm.set_instance_color(index, col)



				



@rpc("any_peer","call_remote")
func request_light_grid(peer_id):
	var voxel_size = World.light_tile_size
	var array = World.light_array
	send_grid.rpc_id(peer_id, voxel_size, array)



@rpc("any_peer","call_remote")
func request_bin_grid(peer_id):
	var voxel_size = World.bin_size
	var array = World.bin_sum_array[0]
	send_grid.rpc_id(peer_id, voxel_size, array)

@rpc("any_peer","call_remote")
func send_grid( voxel_size, array):
	update(voxel_size,array)
