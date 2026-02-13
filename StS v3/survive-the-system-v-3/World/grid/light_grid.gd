extends MeshInstance3D

var voxel_size := 20.0
var occupied_voxels := {}

func _process(delta):
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)

	for key in occupied_voxels.keys():
		draw_voxel_wire(mesh, key)

	mesh.surface_end()
	self.mesh = mesh


func draw_voxel_wire(mesh, key: Vector3i):
	var origin = Vector3(key) * voxel_size
	var s = voxel_size

	var corners = [
		origin,
		origin + Vector3(s,0,0),
		origin + Vector3(s,s,0),
		origin + Vector3(0,s,0),
		origin + Vector3(0,0,s),
		origin + Vector3(s,0,s),
		origin + Vector3(s,s,s),
		origin + Vector3(0,s,s),
	]

	var edges = [
		[0,1],[1,2],[2,3],[3,0],
		[4,5],[5,6],[6,7],[7,4],
		[0,4],[1,5],[2,6],[3,7]
	]

	for e in edges:
		mesh.surface_add_vertex(corners[e[0]])
		mesh.surface_add_vertex(corners[e[1]])
