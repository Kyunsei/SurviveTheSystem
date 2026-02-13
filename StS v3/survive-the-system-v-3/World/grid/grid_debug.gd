extends MultiMeshInstance3D


var voxel_size :Vector3
var isShowing = true
var space_btw_voxel = 0.05



func update(voxel_size,array):
	var box = BoxMesh.new()
	box.size = voxel_size
	box.size.x -= space_btw_voxel
	box.size.z -= space_btw_voxel
	box.size.y -= space_btw_voxel
	
	var World_size = Vector3(100,1,100)

	multimesh.mesh = box   # ← VERY IMPORTANT
	


	#multimesh.transform_format = MultiMesh.TRANSFORM_3D
	#multimesh.color_format = MultiMesh.COLOR_8BIT 
	# Then resize (otherwise, changing the format is not allowed).
	multimesh.instance_count = array.size()#World_size.x * World_size.y * World_size.z
	# Maybe not all of them should be visible at first.
	multimesh.visible_instance_count = array.size()#World_size.x * World_size.y * World_size.z

	# Set the transform of the instances.
	for i in World_size.x:
		for j in World_size.y:
			for k in World_size.z:
				var index = i + j * World_size.x + k * World_size.x * World_size.y
				var pos = Vector3(i +0.5 -World_size.x/2 , j+0.5 , k + 0.5-World_size.z/2) #$size
				multimesh.set_instance_transform(index, Transform3D(Basis(), pos))
				var col = Color()
				col.r = array[index]
				multimesh.set_instance_color(index, col)
