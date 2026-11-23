class_name ForestBase
extends Node3D
## Shared setup for the three forest tests: sky, sun, fog, ground, tree
## placement, trunk collisions, player and helpers. Each forest script
## extends this and only overrides _build_forest().
## All three use the same seed, so the trees are in the same places.
 
@export var tree_count := 2500          ## Target count (glades remove some)
@export var area_size := 220.0          ## Forest is area_size x area_size metres
@export var clearing_radius := 10.0     ## Empty circle around the spawn
@export var random_seed := 1234
@export var chunk_size := 40.0          ## MultiMesh chunk size (for culling)
@export var trunk_collisions := true
@export var shadows := true
@export var uncap_fps := true           ## Turn off vsync so FPS can be compared
 
const VARIANTS := 3
 
class TreeData:
	var position: Vector3
	var yaw: float
	var scale: float
	var variant: int
	var tint: Color
 
var rng := RandomNumberGenerator.new()
var trees: Array[TreeData] = []
var player: TPSPlayer
var sun: DirectionalLight3D
## Shader materials that need the camera position every frame (billboards).
var camera_materials: Array[ShaderMaterial] = []
## Extra line for the HUD, set it in _build_forest().
var info_text := ""
 
 
func _ready() -> void:
	if uncap_fps:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	rng.seed = random_seed
	_build_environment()
	_build_ground()
	_scatter_trees()
	rng.seed = random_seed + 1   # same visual randomness in every test
	_build_forest()
	if trunk_collisions:
		_build_trunk_colliders()
	_spawn_player()
 
 
## Override in each forest script.
func _build_forest() -> void:
	pass
 
## Override to change the HUD title.
func _forest_name() -> String:
	return "Forest"
 
 
func _process(_delta: float) -> void:
	if player and not camera_materials.is_empty():
		var cam_pos := player.get_camera().global_position
		for m in camera_materials:
			m.set_shader_parameter("cam_pos", cam_pos)
 
 
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		sun.shadow_enabled = not sun.shadow_enabled
 
 
# ================================================================ world
 
func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.5, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.86)
	sky_mat.ground_horizon_color = Color(0.6, 0.66, 0.6)
	sky_mat.ground_bottom_color = Color(0.2, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_mat
 
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.68, 0.76, 0.82)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.3
	env.ssao_enabled = true   # Forward+ only, ignored elsewhere
 
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
 
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = shadows
	sun.directional_shadow_max_distance = 120.0
	sun.shadow_blur = 1.5
	add_child(sun)
 
 
func _build_ground() -> void:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.02
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.22, 0.32, 0.13))
	ramp.set_color(1, Color(0.38, 0.42, 0.2))
	var tex := NoiseTexture2D.new()
	tex.noise = noise
	tex.seamless = true
	tex.color_ramp = ramp
	tex.width = 512
	tex.height = 512
 
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.uv1_scale = Vector3(12, 12, 12)
	mat.roughness = 1.0
 
	var plane := PlaneMesh.new()
	plane.size = Vector2(area_size + 200.0, area_size + 200.0)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = mat
	add_child(mi)
 
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	add_child(body)
 
 
func _scatter_trees() -> void:
	# Jittered grid + noise mask: even coverage but with natural glades.
	var density := FastNoiseLite.new()
	density.seed = random_seed
	density.frequency = 0.025
	var cells := int(ceil(sqrt(float(tree_count))))
	var cell := area_size / cells
	var half := area_size * 0.5
	for gx in cells:
		for gz in cells:
			var p := Vector3(
				-half + (gx + rng.randf_range(0.05, 0.95)) * cell,
				0.0,
				-half + (gz + rng.randf_range(0.05, 0.95)) * cell)
			var keep := remap(density.get_noise_2d(p.x, p.z), -0.35, 0.35, 0.1, 1.0)
			if rng.randf() > keep:
				continue
			if Vector2(p.x, p.z).length() < clearing_radius:
				continue
			var t := TreeData.new()
			t.position = p
			t.yaw = rng.randf() * TAU
			t.scale = rng.randf_range(0.75, 1.35)
			t.variant = rng.randi() % VARIANTS
			var v := rng.randf_range(0.85, 1.05)
			t.tint = Color(v * rng.randf_range(0.9, 1.1), v, v * rng.randf_range(0.8, 1.0))
			trees.append(t)
 
 
func _build_trunk_colliders() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 4.0
	for t in trees:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = t.position + Vector3(0, 2.0, 0)
		body.add_child(cs)
 
 
func _spawn_player() -> void:
	player = TPSPlayer.new()
	player.position = Vector3(0, 0.2, 0)
	player.hud_title = _forest_name()
	player.hud_info = info_text
	add_child(player)
 
 
# ================================================================ helpers
 
## Splits instances into MultiMesh chunks so frustum culling still works.
## extra_margin: billboards rotate in the shader, so widen their bounding box.
func spawn_multimesh(mesh: Mesh, xforms: Array[Transform3D], colors: PackedColorArray,
		material: Material, customs := PackedColorArray(), cast_shadow := true,
		extra_margin := 0.0) -> int:
	var buckets := {}
	for i in xforms.size():
		var p := xforms[i].origin
		var key := Vector2i(floori(p.x / chunk_size), floori(p.z / chunk_size))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(i)
 
	var use_custom := not customs.is_empty()
	for key in buckets:
		var idx: Array = buckets[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.use_custom_data = use_custom
		mm.mesh = mesh
		mm.instance_count = idx.size()
		for j in idx.size():
			var i: int = idx[j]
			mm.set_instance_transform(j, xforms[i])
			mm.set_instance_color(j, colors[i])
			if use_custom:
				mm.set_instance_custom_data(j, customs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.extra_cull_margin = extra_margin
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if cast_shadow \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	return buckets.size()
 
 
func tree_transform(t: TreeData) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, t.yaw).scaled(Vector3.ONE * t.scale), t.position)
 
 
## A low-poly frustum/cone (r_top = 0 gives a cone). Emits flat-shaded triangles.
static func add_frustum(st: SurfaceTool, base: Vector3, r_bottom: float, r_top: float,
		height: float, segments: int, col_bottom: Color, col_top: Color,
		r: RandomNumberGenerator = null, jitter := 0.0, cap := true) -> void:
	var b: Array[Vector3] = []
	var t: Array[Vector3] = []
	var off := r.randf() * TAU if r else 0.0
	for i in segments:
		var a := off + TAU * i / segments
		var d := Vector3(cos(a), 0, sin(a))
		var jb := 1.0 + (r.randf_range(-jitter, jitter) if r else 0.0)
		var jt := 1.0 + (r.randf_range(-jitter, jitter) if r else 0.0)
		b.append(base + d * r_bottom * jb)
		t.append(base + Vector3(0, height, 0) + d * r_top * jt)
	var apex := base + Vector3(0, height, 0)
	for i in segments:
		var n := (i + 1) % segments
		if r_top <= 0.001:
			_tri(st, apex, b[i], b[n], col_top, col_bottom, col_bottom)
		else:
			_tri(st, t[n], t[i], b[i], col_top, col_top, col_bottom)
			_tri(st, t[n], b[i], b[n], col_top, col_bottom, col_bottom)
			if cap:
				_tri(st, apex, t[i], t[n], col_top, col_top, col_top)
		if cap:
			_tri(st, base, b[n], b[i], col_bottom, col_bottom, col_bottom)
 
 
## A low-poly lumpy sphere/ellipsoid.
static func add_blob(st: SurfaceTool, center: Vector3, radii: Vector3, segments: int, rings: int,
		col_bottom: Color, col_top: Color, r: RandomNumberGenerator = null, jitter := 0.0) -> void:
	var grid := []
	var off := r.randf() * TAU if r else 0.0
	for ring in rings + 1:
		var row: Array[Vector3] = []
		var phi := PI * ring / rings  # 0 = bottom pole
		for s in segments:
			var a := off + TAU * s / segments
			var d := Vector3(sin(phi) * cos(a), -cos(phi), sin(phi) * sin(a))
			var j := 1.0
			if r and ring > 0 and ring < rings:
				j += r.randf_range(-jitter, jitter)
			row.append(center + d * radii * j)
		grid.append(row)
	for ring in rings:
		var lo: Array[Vector3] = grid[ring]
		var hi: Array[Vector3] = grid[ring + 1]
		var cl := col_bottom.lerp(col_top, float(ring) / rings)
		var ch := col_bottom.lerp(col_top, float(ring + 1) / rings)
		for s in segments:
			var n := (s + 1) % segments
			if ring != rings - 1:
				_tri(st, hi[n], hi[s], lo[s], ch, ch, cl)
			if ring != 0:
				_tri(st, hi[n], lo[s], lo[n], ch, cl, cl)
 
 
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_color(ca); st.add_vertex(a)
	st.set_color(cb); st.add_vertex(b)
	st.set_color(cc); st.add_vertex(c)
 
 
## Starts a SurfaceTool for flat-shaded, vertex-coloured triangles.
static func begin_flat() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # -1 = flat normals
	return st
 
 
static func finish_flat(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()
 
 
## Material for vertex-coloured low-poly meshes (instance colour tints it).
static func vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	return m
 
