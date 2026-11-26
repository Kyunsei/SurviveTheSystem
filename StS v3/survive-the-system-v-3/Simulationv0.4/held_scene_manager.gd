class_name HeldSceneManager
extends Node3D
## Shows a 3D scene in the hands of whoever carries an item that has one.
## Works for every carrier (player or AI): it reads AlifeManager.carriers every frame.
##
## Setup: add this node to your main scene (anywhere), set alifemanager and camera.
## In the item species' _init:
##   held_scene = preload("res://objects/vacuum_held.tscn")
##   held_scene_scale = 1.0
##   held_scene_offset = Vector3(0, 0, 0)       # local: x right, y up, z forward
## The scene is created on pick up, follows the carrier (facing where it faces) and is
## freed when the item is dropped, thrown, eaten or broken. The item's sprite is hidden
## while it's held (hide_sprite_when_held).
##
## The scene's root can have these optional methods:
##   setup(item_species, item_index, carrier_species, carrier_index)   once, on pick up
##   update_held(item_species, item_index)                             every frame
## (e.g. the vacuum's scene can read item_species.is_on[item_index] to animate itself)

@export var alifemanager: AlifeManager
@export var camera: FlyCamera

@export_group("Fill bar")
@export var show_fill_bar := true             # items with fill_ratio() (e.g. the vacuum's tank)
@export var bar_size := Vector2(30, 4)
@export var bar_height := 0.6                 # world units above the held model
@export var bar_empty_color := Color(0.3, 0.8, 1.0)
@export var bar_full_color := Color(1.0, 0.3, 0.2)

var _shown := {}                     # item carry id -> Node3D
var _bars := {}                      # item carry id -> ColorRect (background, fill as child)
var _aoes := {}                      # item carry id -> MeshInstance3D (debug area, aoe_shape())
var _layer := CanvasLayer.new()
var _last_fwd := {}                  # item carry id -> last direction (kept when standing still)


func _ready() -> void:
	_layer.layer = 89                             # just under the controller's HUD
	add_child(_layer)


func _process(_delta: float) -> void:
	if alifemanager == null:
		return
	var center := camera.get_wrap_center() if camera != null else Vector3.ZERO
	var still := {}

	for c in alifemanager.carriers:
		var carrier := alifemanager.split_cid(c)
		var csp = carrier[0]
		var ci: int = carrier[1]
		var item_cid: int = csp.holding[ci]
		if item_cid == -1:
			continue
		var item := alifemanager.split_cid(item_cid)
		var isp = item[0]
		var ii: int = item[1]
		if not ("held_scene" in isp) or isp.held_scene == null:
			continue
		still[item_cid] = true

		var node: Node3D = _shown.get(item_cid)
		if node == null or not is_instance_valid(node):
			node = isp.held_scene.instantiate()
			add_child(node)
			_shown[item_cid] = node
			if node.has_method("setup"):
				node.setup(isp, ii, csp, ci)

		# Where and which way: the carry point, turned like the carrier
		# Anchor: in the hands (carry point in front), or on the carrier itself (backpack...)
		var p: Vector3 = csp.position_array[ci] if isp.held_on_body \
				else alifemanager.carry_position(csp, ci)
		var fwd := Vector3.ZERO
		if "facing" in csp:
			fwd = csp.facing[ci]
		if fwd.length_squared() < 1e-6:
			fwd = csp.current_velocity[ci]
		fwd.y = 0.0
		if fwd.length_squared() > 1e-6:
			fwd = fwd.normalized()
			_last_fwd[item_cid] = fwd            # moving: remember the direction
		else:
			fwd = _last_fwd.get(item_cid, Vector3.FORWARD)   # standing still: keep the last one
		var yaw := atan2(fwd.x, fwd.z)
		var b := Basis(Vector3.UP, yaw).scaled(Vector3.ONE * isp.held_scene_scale)
		var off: Vector3 = isp.held_scene_offset
		if isp.held_offset_with_size:
			off *= csp.current_size[ci]          # a bigger carrier: further up / back
		p += b.orthonormalized() * off
		# Drawn at its copy near the view, on the little planet, like the sprites
		p = WorldWrap.curve(WorldWrap.nearest_image(p, center), center)
		# Fix for models built facing another way (degrees, around the model's own axes)
		var r: Vector3 = isp.held_scene_rotation * (PI / 180.0)
		node.global_transform = Transform3D(b * Basis.from_euler(r), p)

		if node.has_method("update_held"):
			node.update_held(isp, ii)
		_update_bar(item_cid, isp, ii, node.global_position)
		_update_aoe(item_cid, isp, ii, center)

	# Let go of the ones no longer held
	for k in _shown.keys():
		if not still.has(k):
			var n = _shown[k]
			if is_instance_valid(n):
				n.queue_free()
			_shown.erase(k)
			_last_fwd.erase(k)
	for k in _bars.keys():
		if not still.has(k):
			_bars[k].queue_free()
			_bars.erase(k)
	for k in _aoes.keys():
		if not still.has(k):
			_aoes[k].queue_free()
			_aoes.erase(k)


## Debug: wireframe of an item's area (a cone: origin, forward, range, angle_deg, active).
func _update_aoe(item_cid: int, isp, ii: int, center: Vector3) -> void:
	var shape: Dictionary = isp.aoe_shape(ii) if isp.has_method("aoe_shape") else {}
	var mi: MeshInstance3D = _aoes.get(item_cid)
	if shape.is_empty():
		if mi != null:
			mi.visible = false
		return
	if mi == null:
		mi = MeshInstance3D.new()
		mi.mesh = ImmediateMesh.new()
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.vertex_color_use_as_albedo = true
		mat.no_depth_test = true                 # visible through grass
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.top_level = true
		add_child(mi)
		_aoes[item_cid] = mi

	var o: Vector3 = shape["origin"]
	var f: Vector3 = shape["forward"]
	var r: float = shape["range"]
	var a := deg_to_rad(shape["angle_deg"])
	var col := Color(0.3, 1.0, 0.4) if shape["active"] else Color(0.7, 0.7, 0.7)
	var steps := 16
	# Flat world points of the fan, then drawn like the sprites (wrap copy, little planet)
	var pts: Array[Vector3] = [o]
	for k in steps + 1:
		var ang := -a + 2.0 * a * k / steps
		pts.append(o + f.rotated(Vector3.UP, ang) * r)
	for k in pts.size():
		pts[k] = WorldWrap.curve(WorldWrap.nearest_image(pts[k], center), center)

	var im: ImmediateMesh = mi.mesh
	im.clear_surfaces()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_set_color(col)
	im.surface_add_vertex(pts[0]); im.surface_add_vertex(pts[1])           # left edge
	im.surface_add_vertex(pts[0]); im.surface_add_vertex(pts[pts.size() - 1])   # right edge
	im.surface_add_vertex(pts[0]); im.surface_add_vertex(pts[1 + steps / 2])    # middle
	for k in range(1, pts.size() - 1):                                       # arc
		im.surface_add_vertex(pts[k]); im.surface_add_vertex(pts[k + 1])
	im.surface_end()
	mi.global_transform = Transform3D.IDENTITY
	mi.visible = true


## Small bar above the held model: how full the item is (fill_ratio() 0..1, < 0 = no bar).
func _update_bar(item_cid: int, isp, ii: int, at: Vector3) -> void:
	var ratio := -1.0
	if show_fill_bar and isp.has_method("fill_ratio"):
		ratio = isp.fill_ratio(ii)
	var cam := get_viewport().get_camera_3d()
	var above := at + Vector3(0.0, bar_height, 0.0)
	var bar: ColorRect = _bars.get(item_cid)
	if ratio < 0.0 or cam == null or cam.is_position_behind(above):
		if bar != null:
			bar.visible = false
		return
	if bar == null:
		bar = ColorRect.new()
		bar.color = Color(0, 0, 0, 0.6)
		bar.size = bar_size + Vector2(2, 2)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		fill.position = Vector2(1, 1)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(fill)
		_layer.add_child(bar)
		_bars[item_cid] = bar
	ratio = clampf(ratio, 0.0, 1.0)
	var f: ColorRect = bar.get_child(0)
	f.size = Vector2(bar_size.x * ratio, bar_size.y)
	f.color = bar_empty_color.lerp(bar_full_color, ratio)
	bar.position = cam.unproject_position(above) - Vector2(bar.size.x * 0.5, bar.size.y)
	bar.visible = true
