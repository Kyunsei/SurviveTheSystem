extends Node

var alifemanager  :AlifeManager

func _ready() -> void:
	alifemanager =  get_parent().get_node("AlifeManager")

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
	
	



# returns agent index, or -1
func agent_at(world: Vector2, min_pick: float = 0.25) -> int:
	var best := -1
	'var best_d := INF
	for i in alifemanager.entity_count:
		#var d := alifemanager..get_pixel(i % tex_width, i / tex_width)
		if d.b < 0.5:                      # free slot
			continue
		var p := Vector2(d.r, d.g)
		var dd := p.distance_squared_to(world)
		var r := max(d.b * 0.5, min_pick)  # hit radius = half the sprite size
		if dd < r * r and dd < best_d:
			best_d = dd
			best = i'
	return best
	

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_RIGHT \
	and event.pressed:
		var pos := mouse_sim_pos()
		var i := agent_at(pos)
		if i == -1:
			print("no agent at ", pos)
		'else:
			var d := agent_img.get_pixel(i % tex_width, i / tex_width)
			print("agent %d  pos=(%.2f, %.2f)  size=%.2f  state=%.0f"
					% [i, d.r, d.g, d.b, d.a])'
