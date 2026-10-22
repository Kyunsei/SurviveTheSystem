extends Node

#TODO when grid off doesnt work bc global position doesnt exist
#TODO Outline when over or selected

var alifemanager  :AlifeManager
var use_grid := false
var pick_radius_px: float = 6.0   
var selected := -1
var alife_ui_instance := preload("res://Z_TEST/alife_ui.tscn")
var layer := CanvasLayer.new()


func _ready() -> void:
	alifemanager =  get_parent().get_node("AlifeManager")
	add_child(layer)
func mouse_sim_pos() -> Vector2:
	var vp := get_viewport()
	var cam := vp.get_camera_3d()
	if cam != null:
		var mp := vp.get_mouse_position()
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(
				cam.project_ray_origin(mp), cam.project_ray_normal(mp))
		return Vector2(hit.x, hit.z) if hit != null else Vector2.ZERO
	return vp.canvas_transform.affine_inverse() * vp.get_mouse_position()

func mouse_to_ground(y: float = 0.0) -> Vector3:
	var cam := get_viewport().get_camera_3d()
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var dir := cam.project_ray_normal(mp)
	var hit = Plane(Vector3.UP, y).intersects_ray(from, dir)
	return hit if hit != null else Vector3.ZERO
	
	

func display_target_info():

	#var ui := Alife_UI.new()
	var sp_i := alifemanager.global_species_offset.bsearch(selected, false) - 1
	var local_idx := selected - alifemanager.global_species_offset[sp_i]
	
	var ui_i = alife_ui_instance.instantiate()
	layer.add_child(ui_i)
	ui_i.setup(alifemanager.species_array[sp_i],local_idx)




func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT \
	and event.pressed:
		var mouse_pos := mouse_sim_pos()
		#mouse_pos = get_global_mouse_position()
		_pick(mouse_pos)
		if selected > 0:
			display_target_info()
		




## Returns IDs of agents within `radius` of `point`. Uses the grid when it is
## valid, otherwise brute force. Searches one extra cell ring because positions
## have moved one step since the grid was built.
func _query_radius(point: Vector2, radius: float, exclude: int = -1) -> PackedInt32Array:
	var result := PackedInt32Array()
	var r2 := radius * radius
	if not (use_grid):
		for i in alifemanager.entity_count:
			var pos := Vector2(alifemanager.global_position_array[i].x,alifemanager.global_position_array[i].z)
			if i != exclude and pos.distance_squared_to(point) <= r2:
				result.append(i)
		return result

	'var x0 := clampi(int((point.x - radius) * inv_cell) - 1, 0, grid_cols - 1)
	var x1 := clampi(int((point.x + radius) * inv_cell) + 1, 0, grid_cols - 1)
	var y0 := clampi(int((point.y - radius) * inv_cell) - 1, 0, grid_rows - 1)
	var y1 := clampi(int((point.y + radius) * inv_cell) + 1, 0, grid_rows - 1)
	for gy in range(y0, y1 + 1):
		var row := gy * grid_cols
		for gx in range(x0, x1 + 1):
			var cell := row + gx
			for k in range(cell_start[cell], cell_start[cell + 1]):
				var j := cell_agents[k]
				if j != exclude and pos[j].distance_squared_to(point) <= r2:
					result.append(j)'
	return result


func _pick(world_pos: Vector2) -> void:
	selected = -1
	var t0 := Time.get_ticks_usec()
	var r := pick_radius_px #/ cam.zoom.x
	var best := -1
	var best_d := r * r
	for j in _query_radius(world_pos, r):
		var pos := Vector2(alifemanager.global_position_array[j].x,alifemanager.global_position_array[j].z)
		var d := pos.distance_squared_to(world_pos)
		if d < best_d:
			best_d = d
			best = j
	#pick_ms = (Time.get_ticks_usec() - t0) / 1000.0
	#var method := "grid" if (use_grid and grid_valid) else "brute force"

	if best < 0:
		print("No agent at %s " % world_pos)
		# (pick %.3f ms, %s)" % [world_pos, pick_ms, method])
		return
	selected = best
	print("Clicked agent ID: %d  pos: %s" % [
		best, alifemanager.global_position_array[best]])
