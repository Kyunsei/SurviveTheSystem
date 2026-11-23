extends Node3D
## FOREST RENDERING TEST: single script, attach to one Node3D and run.
## Builds sky, sun, ground, a third-person character + camera, and five
## forests you can switch between live from the menu (or keys 1-5):
##   1) classic low poly meshes
##   2) quad billboards (one Y-axis camera-facing quad per tree)
##   3) hybrid: low poly trunk + crown of 3D-placed billboard clumps
##   4) layered sprites: trunk sprite + crown of upright sprites all around it, no 3D mesh
##   5) classic game tree: low poly trunk + branches, crossed leaf cards at branch ends
## The character switches style too: faceted low poly figure / directional
## walking sprite / floating sphere-impostor parts (Rayman style) /
## paper-doll of flat sprite layers / low poly body with hair cards.
## A big horned monster in the clearing also switches between the 5 styles;
## get close and it does a spinning, tilting, flying tornado attack.
## All five use the same tree positions. Each forest is built the first time
## you pick it, then kept, so switching back is instant.
##
## Controls: WASD/arrows move, Shift sprint, Space jump, mouse look, wheel zoom,
## 1-5 switch forest, T shadows, F fog, Tab hide menu,
## Esc free mouse (to click the menu), click in the 3D view to capture again.

enum Mode { LOWPOLY, BILLBOARD, HYBRID, LAYERED, CARDS }
const MODE_NAMES := ["1) Low poly", "2) Quad billboards", "3) Hybrid clumps", "4) Layered sprites", "5) Branches + leaf cards"]

@export var start_mode: Mode = Mode.LOWPOLY
@export var tree_count := 2500          ## Target count (glades remove some)
@export var area_size := 220.0          ## Forest is area_size x area_size metres
@export var clearing_radius := 16.0     ## Empty circle around the spawn (monster lives here)
@export var monster_position := Vector3(0, 0, -10)
@export var tornado_trigger := 6.0     ## Monster attacks when you get this close
@export var random_seed := 1234
@export var chunk_size := 40.0          ## MultiMesh chunk size (for culling)
@export var trunk_collisions := true
@export var uncap_fps := true           ## Vsync off so FPS can be compared
@export var texture_scale := 1.0        ## 2.0 = sharper procedural textures (slower start)
@export_range(0.0, 1.0) var hybrid_normal_blend := 0.7   ## 0 = flat cards, 1 = round crown light
@export var hybrid_wind := 0.03

const VARIANTS := 3   # 0 pine, 1 broadleaf, 2 poplar

class TreeData:
	var position: Vector3
	var yaw: float
	var scale: float
	var variant: int
	var tint: Color

var rng := RandomNumberGenerator.new()
var trees: Array[TreeData] = []
var player: Player
var sun: DirectionalLight3D
var env: Environment

var _mode := -1
var _busy := false
var _forests := {}          # Mode -> Node3D
var _forest_info := {}      # Mode -> String
var _camera_materials: Array[ShaderMaterial] = []
var _colliders: StaticBody3D

# character styles
var _chars := {}            # Mode -> Node3D under player.model
var _lp_parts := {}         # low poly animated nodes
var _hy_parts := {}         # hybrid animated nodes + rest positions
var _sprite_mat: ShaderMaterial
var _cd_parts := {}         # leaf-card mode character (low poly + hair cards)
var _ly_parts := {}         # layered-sprite character nodes + rest positions
var _ly_char_materials: Array[ShaderMaterial] = []

# monster
var _monster_root: Node3D
var _monsters := {}         # Mode -> Node3D
var _monster_parts := {}    # Mode -> {body, head, arm_l, arm_r, ...}
var _monster_cam_materials: Array[ShaderMaterial] = []
var _monster_raise := 0.0
var _monster_motion: Node3D
var _m_attacking := false
var _m_time := 0.0
var _m_cooldown := 0.0
var _m_yaw := 0.0
var _m_spin := 0.0
var _m_target := Vector3.ZERO

# UI
var _menu: Control
var _mode_buttons: Array[Button] = []
var _shadow_check: CheckBox
var _fog_check: CheckBox
var _count_label: Label
var _stats: Label


func _ready() -> void:
	if uncap_fps:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_build_environment()
	_build_ground()
	_spawn_player()
	_build_characters()
	_build_monsters()
	_build_menu()
	_regenerate()


func _process(_delta: float) -> void:
	if player:
		var cam_pos := player.camera.global_position
		for m in _camera_materials:
			m.set_shader_parameter("cam_pos", cam_pos)
		_animate_character()
		_animate_monster(_delta)
		for m in _monster_cam_materials:
			m.set_shader_parameter("cam_pos", cam_pos)
	_update_stats()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_1: set_mode(Mode.LOWPOLY)
		KEY_2: set_mode(Mode.BILLBOARD)
		KEY_3: set_mode(Mode.HYBRID)
		KEY_4: set_mode(Mode.LAYERED)
		KEY_5: set_mode(Mode.CARDS)
		KEY_T:
			sun.shadow_enabled = not sun.shadow_enabled
			_shadow_check.set_pressed_no_signal(sun.shadow_enabled)
		KEY_F:
			env.fog_enabled = not env.fog_enabled
			_fog_check.set_pressed_no_signal(env.fog_enabled)
		KEY_TAB:
			_menu.visible = not _menu.visible


# ================================================================ mode switching

func set_mode(m: int) -> void:
	if _busy or m == _mode:
		return
	_mode = m
	for i in _mode_buttons.size():
		_mode_buttons[i].set_pressed_no_signal(i == m)
	for k in _chars:
		_chars[k].visible = (k == m)
	for k in _monsters:
		_monsters[k].visible = (k == m)
	if not _forests.has(m):
		_busy = true
		_stats.text = "Building %s ..." % MODE_NAMES[m]
		await get_tree().process_frame   # let the label draw before the freeze
		await get_tree().process_frame
		var root := Node3D.new()
		root.name = "Forest_%d" % m
		add_child(root)
		rng.seed = random_seed + 100 + m
		var t0 := Time.get_ticks_msec()
		var info := ""
		match m:
			Mode.LOWPOLY: info = _build_lowpoly(root)
			Mode.BILLBOARD: info = _build_billboard(root)
			Mode.HYBRID: info = _build_hybrid(root)
			Mode.LAYERED: info = _build_layered(root)
			Mode.CARDS: info = _build_cards(root)
		_forests[m] = root
		_forest_info[m] = "%s\nbuilt in %d ms" % [info, Time.get_ticks_msec() - t0]
		_busy = false
	for k in _forests:
		_forests[k].visible = (k == _mode)


func _regenerate() -> void:
	if _busy:
		return
	for f in _forests.values():
		f.queue_free()
	_forests.clear()
	_forest_info.clear()
	_camera_materials.clear()
	if _colliders:
		_colliders.queue_free()
		_colliders = null
	trees.clear()
	rng.seed = random_seed
	_scatter_trees()
	if trunk_collisions:
		_build_trunk_colliders()
	var m := _mode if _mode >= 0 else int(start_mode)
	_mode = -1
	set_mode(m)


# ================================================================ menu

func _build_menu() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	layer.add_child(panel)
	_menu = panel

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.custom_minimum_size.x = 260
	margin.add_child(vb)

	var title := Label.new()
	title.text = "FOREST RENDERING"
	title.add_theme_font_size_override("font_size", 18)
	vb.add_child(title)

	var group := ButtonGroup.new()
	for i in MODE_NAMES.size():
		var b := Button.new()
		b.text = MODE_NAMES[i]
		b.toggle_mode = true
		b.button_group = group
		b.focus_mode = Control.FOCUS_NONE   # so Space doesn't press it
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(set_mode.bind(i))
		vb.add_child(b)
		_mode_buttons.append(b)

	vb.add_child(HSeparator.new())

	_shadow_check = _add_check(vb, "Shadows  (T)", sun.shadow_enabled,
			func(on: bool): sun.shadow_enabled = on)
	_fog_check = _add_check(vb, "Fog  (F)", env.fog_enabled,
			func(on: bool): env.fog_enabled = on)
	_add_check(vb, "VSync", not uncap_fps, _on_vsync_toggled)

	_count_label = Label.new()
	vb.add_child(_count_label)
	var slider := HSlider.new()
	slider.min_value = 250
	slider.max_value = 12000
	slider.step = 250
	slider.value = tree_count
	slider.focus_mode = Control.FOCUS_NONE
	slider.value_changed.connect(_on_count_changed)
	_on_count_changed(tree_count)
	vb.add_child(slider)

	var regen := Button.new()
	regen.text = "Regenerate (new count)"
	regen.focus_mode = Control.FOCUS_NONE
	regen.pressed.connect(_regenerate)
	vb.add_child(regen)

	vb.add_child(HSeparator.new())

	_stats = Label.new()
	vb.add_child(_stats)

	var help := Label.new()
	help.text = "WASD move · Shift sprint · Space jump\nWheel zoom · 1-5 switch · Tab menu\nEsc = mouse for menu, click 3D to look"
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(help)


func _on_vsync_toggled(on: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)


func _on_count_changed(v: float) -> void:
	tree_count = int(v)
	_count_label.text = "Tree count target: %d" % tree_count


func _add_check(parent: Control, text: String, on: bool, cb: Callable) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(cb)
	parent.add_child(c)
	return c


func _update_stats() -> void:
	if _busy or _mode < 0:
		return
	_stats.text = "%s\nFPS: %d   (%.2f ms)\nDraw calls: %d\nPrimitives: %s\n%s" % [
		MODE_NAMES[_mode],
		Engine.get_frames_per_second(),
		1000.0 / maxf(Engine.get_frames_per_second(), 1.0),
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		String.num_int64(int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))),
		_forest_info.get(_mode, ""),
	]


# ================================================================ world

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.5, 0.78)
	sky_mat.sky_horizon_color = Color(0.72, 0.8, 0.86)
	sky_mat.ground_horizon_color = Color(0.6, 0.66, 0.6)
	sky_mat.ground_bottom_color = Color(0.2, 0.24, 0.2)
	var sky := Sky.new()
	sky.sky_material = sky_mat

	env = Environment.new()
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
	sun.shadow_enabled = true
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
	_colliders = StaticBody3D.new()
	add_child(_colliders)
	var shape := CylinderShape3D.new()
	shape.radius = 0.3
	shape.height = 4.0
	for t in trees:
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = t.position + Vector3(0, 2.0, 0)
		_colliders.add_child(cs)


func _spawn_player() -> void:
	player = Player.new()
	player.position = Vector3(0, 0.2, 0)
	add_child(player)


# ================================================================ 1) LOW POLY

const BARK := Color(0.33, 0.22, 0.14)
const BARK_DARK := Color(0.2, 0.13, 0.08)


func _build_lowpoly(root: Node3D) -> String:
	var meshes: Array[ArrayMesh] = [_lp_pine(), _lp_broadleaf(), _lp_poplar()]
	var mat := vertex_color_material()
	var tri_info := PackedStringArray()
	for v in VARIANTS:
		var xforms: Array[Transform3D] = []
		var colors := PackedColorArray()
		for t in trees:
			if t.variant == v:
				xforms.append(tree_transform(t))
				colors.append(t.tint)
		spawn_multimesh(root, meshes[v], xforms, colors, mat)
		tri_info.append(str(int(meshes[v].surface_get_array_len(0) / 3.0)))
	return "Trees: %d\ntris/tree (pine/round/poplar): %s" % [trees.size(), " / ".join(tri_info)]


func _lp_pine() -> ArrayMesh:
	var st := begin_flat()
	add_frustum(st, Vector3.ZERO, 0.28, 0.14, 2.0, 6, BARK_DARK, BARK, rng, 0.1)
	var dark := Color(0.08, 0.22, 0.12)
	var light := Color(0.2, 0.42, 0.2)
	var layers := [[1.1, 2.1, 2.5], [2.4, 1.65, 2.3], [3.7, 1.15, 2.1]]  # y, radius, height
	for i in layers.size():
		var l: Array = layers[i]
		add_frustum(st, Vector3(0, l[0], 0), l[1], 0.0, l[2], 8,
				dark.lerp(light, i * 0.25), light.lerp(Color(0.35, 0.55, 0.25), i * 0.2), rng, 0.15)
	return finish_flat(st)


func _lp_broadleaf() -> ArrayMesh:
	var st := begin_flat()
	add_frustum(st, Vector3.ZERO, 0.32, 0.2, 2.8, 6, BARK_DARK, BARK, rng, 0.1)
	var dark := Color(0.13, 0.3, 0.1)
	var light := Color(0.38, 0.58, 0.2)
	add_blob(st, Vector3(0, 4.0, 0), Vector3(2.0, 1.6, 2.0), 8, 5, dark, light, rng, 0.14)
	add_blob(st, Vector3(1.3, 3.4, 0.5), Vector3(1.25, 1.05, 1.25), 7, 4, dark, light, rng, 0.14)
	add_blob(st, Vector3(-1.1, 3.6, -0.7), Vector3(1.3, 1.1, 1.3), 7, 4, dark, light, rng, 0.14)
	add_blob(st, Vector3(0.2, 5.1, 0.2), Vector3(1.2, 1.0, 1.2), 7, 4, dark, light.lightened(0.1), rng, 0.14)
	return finish_flat(st)


func _lp_poplar() -> ArrayMesh:
	var st := begin_flat()
	add_frustum(st, Vector3.ZERO, 0.22, 0.12, 3.2, 6, Color(0.55, 0.52, 0.47), Color(0.75, 0.73, 0.68), rng, 0.08)
	var dark := Color(0.16, 0.32, 0.12)
	var light := Color(0.45, 0.6, 0.22)
	add_blob(st, Vector3(0, 5.2, 0), Vector3(1.35, 3.0, 1.35), 7, 6, dark, light, rng, 0.12)
	add_blob(st, Vector3(0.3, 7.6, 0.1), Vector3(0.7, 1.0, 0.7), 6, 3, dark.lerp(light, 0.6), light, rng, 0.1)
	return finish_flat(st)


# ================================================================ 2) QUAD BILLBOARDS

const BILLBOARD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 cam_pos;
uniform vec2 quad_size = vec2(4.0, 8.0);
uniform float alpha_cut = 0.5;
uniform float bulge = 0.7;        // fake round normal so light wraps around the tree
uniform float mip_alpha_boost = 0.35;
uniform float roll = 0.0;         // in-plane rotation around the quad centre (fake tilt)
uniform float flip = 0.0;         // 1 = mirror horizontally (fake turning around)

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	vec3 to_cam = cam_pos - origin;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = cross(up, fwd);
	if (flip > 0.5) {
		UV.x = 1.0 - UV.x;
	}
	if (abs(roll) > 0.0001) {
		vec2 c = vec2(0.0, quad_size.y * 0.5);
		vec2 v = VERTEX.xy - c;
		VERTEX.xy = c + vec2(cos(roll) * v.x - sin(roll) * v.y, sin(roll) * v.x + cos(roll) * v.y);
	}
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0),
			vec4(fwd * sx, 0.0), vec4(origin, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(right, up, fwd);
	vec2 q = vec2(VERTEX.x / (quad_size.x * 0.5), (VERTEX.y / quad_size.y) * 2.0 - 1.0);
	NORMAL = normalize(vec3(q.x * bulge, q.y * bulge * 0.6 + 0.25, 1.0));
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 dx = dFdx(UV * ts);
	vec2 dy = dFdy(UV * ts);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	ALBEDO = c.rgb * pow(COLOR.rgb, vec3(2.2));   // tint is sRGB
	ALPHA = c.a * (1.0 + lod * mip_alpha_boost);   // stops far trees thinning out
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = c.rgb * 0.25;
}
"""

# per variant: texture pixel size, quad size in metres (matches the low poly trees)
const BB_KINDS := [
	{"px": Vector2i(256, 384), "quad": Vector2(4.2, 6.3)},   # pine
	{"px": Vector2i(384, 384), "quad": Vector2(6.4, 6.4)},   # broadleaf
	{"px": Vector2i(192, 512), "quad": Vector2(3.4, 9.0)},   # poplar
]


func _build_billboard(root: Node3D) -> String:
	var shader := Shader.new()
	shader.code = BILLBOARD_SHADER
	for v in VARIANTS:
		var info: Dictionary = BB_KINDS[v]
		var quad_size: Vector2 = info["quad"]
		var quad := QuadMesh.new()
		quad.size = quad_size
		quad.center_offset = Vector3(0, quad_size.y * 0.5, 0)   # pivot at the bottom

		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", _bb_texture(v, info["px"]))
		mat.set_shader_parameter("quad_size", quad_size)
		_camera_materials.append(mat)

		var xforms: Array[Transform3D] = []
		var colors := PackedColorArray()
		for t in trees:
			if t.variant == v:
				xforms.append(Transform3D(Basis().scaled(Vector3.ONE * t.scale), t.position))
				colors.append(t.tint)
		spawn_multimesh(root, quad, xforms, colors, mat, PackedColorArray(), true, quad_size.x)
	return "Trees: %d  (2 tris each)" % trees.size()


func _bb_texture(kind: int, px: Vector2i) -> ImageTexture:
	var w := int(px.x * texture_scale)
	var h := int(px.y * texture_scale)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.2, 0.33, 0.15, 0.0))   # transparent but leaf-coloured: no dark fringes

	var leaf_noise := FastNoiseLite.new()
	leaf_noise.seed = rng.randi()
	leaf_noise.frequency = 0.09 / texture_scale
	var edge_noise := FastNoiseLite.new()
	edge_noise.seed = rng.randi()
	edge_noise.frequency = 0.05 / texture_scale

	match kind:
		0:
			_paint_trunk(img, 0.55, 0.06, Color(0.3, 0.2, 0.12))
			_paint_pine(img, leaf_noise, edge_noise)
		1:
			_paint_trunk(img, 0.5, 0.06, Color(0.33, 0.22, 0.14))
			_paint_blobs(img, leaf_noise, edge_noise, Vector2(0.5, 0.38), Vector2(0.42, 0.32),
					48, Vector2(0.09, 0.15), Color(0.2, 0.42, 0.14))
		2:
			_paint_trunk(img, 0.5, 0.08, Color(0.7, 0.68, 0.63))
			_paint_blobs(img, leaf_noise, edge_noise, Vector2(0.5, 0.38), Vector2(0.4, 0.34),
					40, Vector2(0.18, 0.28), Color(0.26, 0.45, 0.15))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


func _paint_trunk(img: Image, start_y: float, width: float, col: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w * 0.5
	for y in range(int(h * start_y), h):
		var f := float(y - h * start_y) / (h * (1.0 - start_y))
		var hw := w * width * (0.7 + 0.5 * f) * 0.5 + 1.0
		for x in range(maxi(0, int(cx - hw)), mini(w, int(cx + hw) + 1)):
			var s := 1.15 - 0.5 * (x - (cx - hw)) / (2.0 * hw)   # lit from the left
			s *= 0.9 + 0.2 * rng.randf()
			img.set_pixel(x, y, Color(col.r * s, col.g * s, col.b * s, 1.0))


func _paint_pine(img: Image, leaf: FastNoiseLite, edge: FastNoiseLite) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var cx := w * 0.5
	var top := int(h * 0.03)
	var bottom := int(h * 0.82)
	var tiers := 5.0
	var dark := Color(0.07, 0.2, 0.1)
	var light := Color(0.24, 0.45, 0.22)
	for y in range(top, bottom):
		var f := float(y - top) / (bottom - top)
		var tier := fmod(f * tiers, 1.0)          # 0 = top of a tier, 1 = its lower edge
		var hw := (0.08 + 0.38 * f) * w * (0.5 + 0.5 * tier)
		for x in range(maxi(0, int(cx - hw - 12)), mini(w, int(cx + hw + 12))):
			var dx := float(x) - cx
			if absf(dx) > hw + edge.get_noise_2d(x, y) * 10.0 * texture_scale:
				continue
			var side := 0.5 - 0.5 * dx / maxf(hw, 1.0)   # 1 on the lit left side
			var s := 0.55 + 0.35 * side + 0.25 * (1.0 - tier) + 0.25 * leaf.get_noise_2d(x, y)
			var c := dark.lerp(light, clampf(s, 0.0, 1.2))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))


## Canopy of round leaf clumps, painted back (dark) to front (light).
func _paint_blobs(img: Image, leaf: FastNoiseLite, edge: FastNoiseLite, center: Vector2,
		radii: Vector2, count: int, rad_range: Vector2, base: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var c0 := Vector2(center.x * w, center.y * h)
	var rad := Vector2(radii.x * w, radii.y * h)
	var blobs := []
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * 0.78
		var p := c0 + Vector2(cos(a) * rad.x, sin(a) * rad.y) * d
		var r := rng.randf_range(rad_range.x, rad_range.y) * w
		var rel := (p - c0) / rad
		var shade := 0.75 + 0.175 * (-rel.y) + 0.1 * (-rel.x) + rng.randf_range(-0.1, 0.1)
		shade -= 0.25 * (1.0 - d)   # inner clumps sit deeper = darker
		blobs.append([shade, p, r])
	blobs.sort_custom(func(a, b): return a[0] < b[0])

	for b in blobs:
		var shade: float = b[0]
		var p: Vector2 = b[1]
		var r: float = b[2]
		for y in range(maxi(0, int(p.y - r * 1.2)), mini(h, int(p.y + r * 1.2))):
			for x in range(maxi(0, int(p.x - r * 1.2)), mini(w, int(p.x + r * 1.2))):
				var o := Vector2(x, y) - p
				if o.length() > r * (1.0 + 0.22 * edge.get_noise_2d(x, y)):
					continue
				var local := 1.0 + 0.3 * (o / r).dot(Vector2(-0.7, -0.7))   # lit from top-left
				var s := shade * local * (0.8 + 0.35 * leaf.get_noise_2d(x, y))
				img.set_pixel(x, y, Color(base.r * s, base.g * s, base.b * s, 1.0))


# ================================================================ 3) HYBRID

const HYBRID_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 cam_pos;
uniform float alpha_cut = 0.45;
uniform float normal_blend = 0.7;
uniform float mip_alpha_boost = 0.35;
uniform float wind = 0.03;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float s = length(MODEL_MATRIX[0].xyz);
	origin.xz += vec2(sin(TIME * 1.3 + origin.x * 0.35), cos(TIME * 1.1 + origin.z * 0.35))
			* wind * origin.y;   // sway, stronger higher up

	// full spherical billboard pointing at the camera
	vec3 fwd = cam_pos - origin;
	fwd = length(fwd) > 0.001 ? normalize(fwd) : vec3(0.0, 0.0, 1.0);
	vec3 up_ref = abs(fwd.y) > 0.99 ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up_ref, fwd));
	vec3 up = cross(fwd, right);
	mat3 bb = mat3(right, up, fwd);

	// random in-plane spin so clumps don't look repeated
	float a = INSTANCE_CUSTOM.w * 6.28318;
	float ca = cos(a);
	float sa = sin(a);
	VERTEX.xy = vec2(ca * VERTEX.x - sa * VERTEX.y, sa * VERTEX.x + ca * VERTEX.y);

	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * s, 0.0), vec4(up * s, 0.0),
			vec4(fwd * s, 0.0), vec4(origin, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * bb;

	// blend the card's own round normal with "outward from the crown centre"
	vec3 card_n = normalize(vec3(VERTEX.xy * 1.2, 1.0));
	vec3 crown_dir = normalize(INSTANCE_CUSTOM.xyz * 2.0 - 1.0);   // stored as 0..1
	vec3 crown_n = transpose(bb) * crown_dir;
	NORMAL = normalize(mix(card_n, crown_n, normal_blend));
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 dx = dFdx(UV * ts);
	vec2 dy = dFdy(UV * ts);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	vec3 tint = pow(COLOR.rgb, vec3(2.2));   // instance colour is sRGB
	ALBEDO = c.rgb * tint;
	ALPHA = c.a * (1.0 + lod * mip_alpha_boost);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = c.rgb * tint * 0.4;
}
"""

const LEAF_COLORS: Array[Color] = [
	Color(0.34, 0.6, 0.34),   # pine
	Color(0.5, 0.78, 0.3),    # broadleaf
	Color(0.56, 0.78, 0.34),  # poplar
]


func _build_hybrid(root: Node3D) -> String:
	var shader := Shader.new()
	shader.code = HYBRID_SHADER
	var leaf_tex := _clump_texture(int(128 * texture_scale), 7.0, 3.2, 240)
	var needle_tex := _clump_texture(int(128 * texture_scale), 9.0, 1.4, 520)

	var card := QuadMesh.new()
	card.size = Vector2.ONE

	var trunk_mat := vertex_color_material()
	var trunks: Array[ArrayMesh] = [
		_hy_trunk(0.26, 0.05, 5.6, Color(0.2, 0.13, 0.08), Color(0.33, 0.22, 0.14)),
		_hy_trunk(0.32, 0.17, 3.6, Color(0.2, 0.13, 0.08), Color(0.33, 0.22, 0.14)),
		_hy_trunk(0.22, 0.06, 6.8, Color(0.5, 0.48, 0.43), Color(0.75, 0.73, 0.68)),
	]
	var templates := [
		_crown_pine(),
		_crown_ellipsoid(Vector3(0, 4.1, 0), Vector3(1.65, 1.3, 1.65), 16, 2.3),
		_crown_ellipsoid(Vector3(0, 5.3, 0), Vector3(0.9, 2.7, 0.9), 14, 1.7) \
				+ [[Vector3(0, 8.0, 0), 1.2, Vector3.UP]],
	]

	var card_total := 0
	for v in VARIANTS:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", needle_tex if v == 0 else leaf_tex)
		mat.set_shader_parameter("normal_blend", hybrid_normal_blend)
		mat.set_shader_parameter("wind", hybrid_wind)
		_camera_materials.append(mat)

		var trunk_x: Array[Transform3D] = []
		var trunk_c := PackedColorArray()
		var card_x: Array[Transform3D] = []
		var card_c := PackedColorArray()
		var card_custom := PackedColorArray()
		var tpl: Array = templates[v]

		for t in trees:
			if t.variant != v:
				continue
			var xf := tree_transform(t)
			trunk_x.append(xf)
			trunk_c.append(t.tint)
			for clump in tpl:
				var local: Vector3 = clump[0]
				local += Vector3(rng.randf_range(-0.15, 0.15), rng.randf_range(-0.1, 0.1), rng.randf_range(-0.15, 0.15))
				var size: float = clump[1] * t.scale * rng.randf_range(0.85, 1.15)
				var dir: Vector3 = xf.basis.orthonormalized() * (clump[2] as Vector3)
				card_x.append(Transform3D(Basis().scaled(Vector3.ONE * size), xf * local))
				var ao := 0.7 + 0.3 * (dir.y * 0.5 + 0.5)   # undersides darker
				var col := LEAF_COLORS[v] * t.tint * ao
				col.a = 1.0
				card_c.append(col)
				var enc := dir * 0.5 + Vector3(0.5, 0.5, 0.5)
				card_custom.append(Color(enc.x, enc.y, enc.z, rng.randf()))

		spawn_multimesh(root, trunks[v], trunk_x, trunk_c, trunk_mat)
		spawn_multimesh(root, card, card_x, card_c, mat, card_custom, true, 2.0)
		card_total += card_x.size()
	return "Trees: %d   clump cards: %d" % [trees.size(), card_total]


func _hy_trunk(r0: float, r1: float, h: float, c0: Color, c1: Color) -> ArrayMesh:
	var st := begin_flat()
	add_frustum(st, Vector3.ZERO, r0, r1, h, 6, c0, c1, rng, 0.1)
	return finish_flat(st)


## Crown template entries: [local position, card size (m), outward direction for lighting]
func _crown_ellipsoid(center: Vector3, radii: Vector3, count: int, size: float) -> Array:
	var out := []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in count:
		var y := 1.0 - 2.0 * (i + 0.5) / count     # fibonacci sphere
		var r := sqrt(1.0 - y * y)
		var a := golden * i
		var n := Vector3(cos(a) * r, y, sin(a) * r)
		out.append([center + n * radii * 0.8, size, n])
	for i in 3:   # a few inner clumps fill gaps
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.3, 1), rng.randf_range(-1, 1)).normalized()
		out.append([center + n * radii * 0.35, size * 0.9, n])
	return out


func _crown_pine() -> Array:
	var out := []
	var tiers := 5
	for k in tiers:
		var f := float(k) / (tiers - 1)
		var y := lerpf(1.6, 5.2, f)
		var radius := 1.75 * (1.0 - f * 0.75)
		var n_ring := maxi(3, int(round(7.0 * (1.0 - f * 0.6))))
		var off := rng.randf() * TAU
		for i in n_ring:
			var a := off + TAU * i / n_ring
			var p := Vector3(cos(a) * radius * 0.8, y, sin(a) * radius * 0.8)
			var dir := (p - Vector3(0, y - 0.9, 0)).normalized()   # outward + up, like a cone
			out.append([p, 1.5 * (1.0 - f * 0.45), dir])
	out.append([Vector3(0, 5.9, 0), 0.9, Vector3.UP])
	return out


## Round clump of leaves (or needles when leaf_w is small), grey-green so the
## per-instance colour does the tinting.
func _clump_texture(size: int, leaf_len: float, leaf_w: float, count: int) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.9, 0.7, 0.0))
	var k := size / 128.0
	leaf_len *= k
	leaf_w *= k
	var c := Vector2(size, size) * 0.5
	var R := size * 0.47
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.08 / k

	# solid core so the clump stays opaque at a distance (mipmaps)
	for y in size:
		for x in size:
			var o := Vector2(x, y) - c
			if o.length() < R * 0.55 * (1.0 + 0.15 * noise.get_noise_2d(x, y)):
				var v := 0.5 + 0.15 * noise.get_noise_2d(x * 2.0, y * 2.0)
				img.set_pixel(x, y, Color(v * 0.85, v, v * 0.8, 1.0))

	var leaves := []
	for i in count:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf()) * (R - leaf_len)
		var p := c + Vector2(cos(a), sin(a)) * d
		var rel := (p - c) / R
		var v := 0.72 + 0.28 * rel.dot(Vector2(-0.7, -0.7)) + rng.randf_range(-0.15, 0.15)
		v += 0.15 * (d / R)   # outer leaves catch more light
		leaves.append([v, p, a + rng.randf_range(-0.8, 0.8)])
	leaves.sort_custom(func(l1, l2): return l1[0] < l2[0])

	for l in leaves:
		var v: float = l[0]
		var p: Vector2 = l[1]
		var ca := cos(l[2] as float)
		var sa := sin(l[2] as float)
		var ext := int(ceil(leaf_len)) + 1
		for y in range(maxi(0, int(p.y) - ext), mini(size, int(p.y) + ext + 1)):
			for x in range(maxi(0, int(p.x) - ext), mini(size, int(p.x) + ext + 1)):
				var o := Vector2(x, y) - p
				var u := o.x * ca + o.y * sa
				var w := -o.x * sa + o.y * ca
				if (u / leaf_len) * (u / leaf_len) + (w / leaf_w) * (w / leaf_w) > 1.0:
					continue
				var s := v * (0.85 + 0.25 * (1.0 - absf(w) / leaf_w))   # midrib highlight
				img.set_pixel(x, y, Color(s * 0.85, s, s * 0.8, 1.0))

	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ================================================================ 4) LAYERED SPRITES
# No 3D mesh at all: a trunk sprite plus a crown of 9-14 big upright leaf-mass
# sprites spread all AROUND the crown in 3D (like mode 3, but fewer, bigger,
# and Y-axis billboards, so they stay upright like painted layers).
# Each sprite gets a normal bent outward from the crown centre, so the light
# wraps around the whole tree: lit side bright, far side and underside dark.
# Colours use the same leaf palette, tint and fake AO as mode 3.

const LAYER_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform vec3 cam_pos;
uniform vec2 quad_size = vec2(2.0, 2.0);
uniform float alpha_cut = 0.45;
uniform float normal_blend = 0.7;   // 0 = flat sprite, 1 = full crown normal
uniform float mip_alpha_boost = 0.35;
uniform float wind = 0.03;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sy = length(MODEL_MATRIX[1].xyz);
	origin.xz += vec2(sin(TIME * 1.3 + origin.x * 0.35), cos(TIME * 1.1 + origin.z * 0.35))
			* wind * max(origin.y - 1.0, 0.0);

	// Y-axis billboard (stays upright) facing the camera position
	vec3 to_cam = cam_pos - origin;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = cross(up, fwd);
	mat3 bb = mat3(right, up, fwd);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * sx, 0.0), vec4(up * sy, 0.0),
			vec4(fwd * sx, 0.0), vec4(origin, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * bb;

	// mirror half of the sprites so repeats are less obvious
	if (INSTANCE_CUSTOM.w > 0.5) {
		UV.x = 1.0 - UV.x;
	}

	// round normal of the sprite itself, blended with "outward from the crown"
	vec2 q = VERTEX.xy / (quad_size * 0.5);   // quad is centred: -1..1
	vec3 card_n = normalize(vec3(q.x * 0.8, q.y * 0.5, 1.0));
	vec3 crown_dir = normalize(INSTANCE_CUSTOM.xyz * 2.0 - 1.0);   // stored as 0..1
	vec3 crown_n = transpose(bb) * crown_dir;
	NORMAL = normalize(mix(card_n, crown_n, normal_blend));
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 dx = dFdx(UV * ts);
	vec2 dy = dFdy(UV * ts);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	vec3 tint = pow(COLOR.rgb, vec3(2.2));   // instance colour is sRGB
	ALBEDO = c.rgb * tint;
	ALPHA = c.a * (1.0 + lod * mip_alpha_boost);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
	BACKLIGHT = c.rgb * tint * 0.4;
}
"""

const LAYER_TRUNKS := [
	["trunk_pine", Vector2(0.8, 5.8)],
	["trunk_branchy", Vector2(1.6, 3.2)],
	["trunk_light", Vector2(0.8, 6.0)],
]


func _build_layered(root: Node3D) -> String:
	var shader := Shader.new()
	shader.code = LAYER_SHADER
	# grey-green textures: the per-instance colour does the tinting (like mode 3)
	var neutral := Color(0.72, 0.86, 0.64)
	var tex := {
		"round": _layer_mass_texture(256, 224, neutral, 30),
		"tall": _layer_mass_texture(160, 320, neutral, 30),
		"tier": _layer_tier_texture(256, 140),
		"trunk_pine": _layer_trunk_texture(64, 384, Color(0.3, 0.2, 0.12), false),
		"trunk_branchy": _layer_trunk_texture(128, 256, Color(0.33, 0.22, 0.14), true),
		"trunk_light": _layer_trunk_texture(64, 384, Color(0.72, 0.7, 0.65), false),
	}
	# crown templates: entries [texture, size (m), local centre, outward dir]
	var templates := [_layer_crown_pine(), _layer_crown_round(), _layer_crown_tall()]

	var sprite_total := 0
	for v in VARIANTS:
		# group this variant's sprites by (texture, size) -> one MultiMesh each
		var groups := {}
		var trunk: Array = LAYER_TRUNKS[v]
		groups["trunk"] = _sprite_group(trunk[0], trunk[1])
		var tpl: Array = templates[v]
		for i in tpl.size():
			groups[i] = _sprite_group(tpl[i][0], tpl[i][1])

		for t in trees:
			if t.variant != v:
				continue
			var xf := tree_transform(t)
			var g: Dictionary = groups["trunk"]
			g["x"].append(Transform3D(Basis().scaled(Vector3.ONE * t.scale), t.position))
			g["c"].append(t.tint.lerp(Color.WHITE, 0.5))
			g["u"].append(Color(0.5, 1.0, 0.5, 0.0))
			for i in tpl.size():
				var e: Array = tpl[i]
				var local: Vector3 = e[2]
				local += Vector3(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.08, 0.08), rng.randf_range(-0.12, 0.12))
				var dir: Vector3 = xf.basis.orthonormalized() * (e[3] as Vector3)
				var sc := t.scale * rng.randf_range(0.88, 1.12)
				g = groups[i]
				g["x"].append(Transform3D(Basis().scaled(Vector3.ONE * sc), xf * local))
				var ao := 0.7 + 0.3 * (dir.y * 0.5 + 0.5)   # undersides darker
				var col := LEAF_COLORS[v] * t.tint * ao
				col.a = 1.0
				g["c"].append(col)
				var enc := dir * 0.5 + Vector3(0.5, 0.5, 0.5)
				g["u"].append(Color(enc.x, enc.y, enc.z, rng.randf()))

		for key in groups:
			var g: Dictionary = groups[key]
			var size: Vector2 = g["size"]
			var is_trunk: bool = key is String
			var quad := QuadMesh.new()
			quad.size = size
			if is_trunk:
				quad.center_offset = Vector3(0, size.y * 0.5, 0)   # trunk pivots at its base
			var mat := ShaderMaterial.new()
			mat.shader = shader
			mat.set_shader_parameter("tex", tex[g["tex"]])
			mat.set_shader_parameter("quad_size", size)
			mat.set_shader_parameter("normal_blend", 0.0 if is_trunk else hybrid_normal_blend)
			mat.set_shader_parameter("wind", 0.0 if is_trunk else hybrid_wind)
			if is_trunk:
				# the trunk pivots at its base, not its centre: make the fake roundness
				# sideways only so its top isn't lit like a dome
				mat.set_shader_parameter("quad_size", Vector2(size.x, size.y * 1000.0))
			_camera_materials.append(mat)
			var xforms: Array[Transform3D] = g["x"]
			spawn_multimesh(root, quad, xforms, PackedColorArray(g["c"]), mat,
					PackedColorArray(g["u"]), true, maxf(size.x, size.y))
			sprite_total += xforms.size()
	return "Trees: %d   sprites: %d  (0 meshes)" % [trees.size(), sprite_total]


## One MultiMesh worth of sprites. Colours are kept in plain Arrays while
## filling (packed arrays inside a Dictionary don't keep appended values).
func _sprite_group(tex_key: String, size: Vector2) -> Dictionary:
	var xforms: Array[Transform3D] = []
	return {"tex": tex_key, "size": size, "x": xforms, "c": [], "u": []}


## Round crown: leaf masses on a fibonacci ellipsoid + a couple inside.
func _layer_crown_round() -> Array:
	var out := _layer_ellipsoid("round", Vector3(0, 4.0, 0), Vector3(1.6, 1.25, 1.6), 11, Vector2(2.6, 2.3))
	for i in 2:
		var n := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized()
		out.append(["round", Vector2(2.4, 2.1), Vector3(0, 4.0, 0) + n * Vector3(0.5, 0.4, 0.5), n])
	return out


func _layer_crown_tall() -> Array:
	var out := _layer_ellipsoid("tall", Vector3(0, 5.2, 0), Vector3(0.85, 2.4, 0.85), 9, Vector2(1.9, 2.7))
	out.append(["tall", Vector2(1.3, 1.9), Vector3(0, 7.6, 0), Vector3.UP])
	return out


## Pine: rings of needle tiers around the trunk, smaller towards the top.
func _layer_crown_pine() -> Array:
	var out := []
	var levels := 5
	for k in levels:
		var f := float(k) / (levels - 1)
		var y := lerpf(1.9, 5.0, f)
		var ring := 1.0 * (1.0 - f * 0.7)
		var w := 2.7 * (1.0 - f * 0.55)
		var count := maxi(3, int(round(5.0 - f * 2.0)))
		var off := rng.randf() * TAU
		for i in count:
			var a := off + TAU * i / count
			var p := Vector3(cos(a) * ring * 0.8, y, sin(a) * ring * 0.8)
			var dir := (p - Vector3(0, y - 0.9, 0)).normalized()   # outward + up, like a cone
			out.append(["tier", Vector2(w, w * 0.6), p, dir])
	out.append(["tier", Vector2(1.2, 1.1), Vector3(0, 5.75, 0), Vector3.UP])
	return out


func _layer_ellipsoid(tex_key: String, center: Vector3, radii: Vector3, count: int, size: Vector2) -> Array:
	var out := []
	var golden := PI * (3.0 - sqrt(5.0))
	for i in count:
		var y := 1.0 - 2.0 * (i + 0.5) / count     # fibonacci sphere
		var r := sqrt(1.0 - y * y)
		var a := golden * i
		var n := Vector3(cos(a) * r, y, sin(a) * r)
		out.append([tex_key, size, center + n * radii * 0.7, n])
	return out


## One big leaf mass made of clumps (transparent around it).
func _layer_mass_texture(w: int, h: int, base: Color, count: int) -> ImageTexture:
	w = int(w * texture_scale)
	h = int(h * texture_scale)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(base.r, base.g, base.b, 0.0))
	var leaf := FastNoiseLite.new()
	leaf.seed = rng.randi()
	leaf.frequency = 0.09 / texture_scale
	var edge := FastNoiseLite.new()
	edge.seed = rng.randi()
	edge.frequency = 0.05 / texture_scale
	# sizes chosen so clumps never touch the image border (no straight cut edges)
	var tall := h > w
	var radii := Vector2(0.28, 0.38) if tall else Vector2(0.28, 0.3)
	var clump := Vector2(0.14, 0.2) if tall else Vector2(0.1, 0.15)
	_paint_blobs(img, leaf, edge, Vector2(0.5, 0.5), radii, count, clump, base)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## One jagged pine tier (a wide skirt of needles), lit from the left.
func _layer_tier_texture(w: int, h: int) -> ImageTexture:
	w = int(w * texture_scale)
	h = int(h * texture_scale)
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.6, 0.72, 0.58, 0.0))
	var leaf := FastNoiseLite.new()
	leaf.seed = rng.randi()
	leaf.frequency = 0.1 / texture_scale
	var edge := FastNoiseLite.new()
	edge.seed = rng.randi()
	edge.frequency = 0.12 / texture_scale
	# grey-green, tinted per instance (same palette as mode 3)
	var dark := Color(0.32, 0.42, 0.3)
	var light := Color(0.85, 1.0, 0.8)
	var cx := w * 0.5
	for y in range(int(h * 0.04), int(h * 0.96)):
		var f := float(y) / h                       # 0 top .. 1 bottom
		var hw := w * 0.47 * pow(f, 0.85)
		var jag := 0.9 + 0.1 * sin(float(y) * 0.9 / texture_scale)   # hanging needle tips
		for x in range(maxi(0, int(cx - hw - 10)), mini(w, int(cx + hw + 10))):
			var dx := float(x) - cx
			if absf(dx) > hw * jag + edge.get_noise_2d(x, y) * 9.0 * texture_scale:
				continue
			if f > 0.85 and edge.get_noise_2d(x * 3.0, 0.0) < (f - 0.85) * 6.0 - 0.3:
				continue   # ragged bottom edge
			var side := 0.5 - 0.5 * dx / maxf(hw, 1.0)
			var s := 0.45 + 0.35 * side + 0.3 * (1.0 - f) + 0.25 * leaf.get_noise_2d(x, y)
			var c := dark.lerp(light, clampf(s, 0.0, 1.2))
			img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## Trunk sprite, tapering, optionally with a few branches (hidden by leaves up top).
func _layer_trunk_texture(w: int, h: int, col: Color, branches: bool) -> ImageTexture:
	var k := texture_scale
	var img := Image.create_empty(int(w * k), int(h * k), false, Image.FORMAT_RGBA8)
	img.fill(Color(col.r, col.g, col.b, 0.0))
	var cx := w * 0.5
	var base_r := w * (0.09 if branches else 0.16)
	# taper: stack of capsules getting thinner towards the top
	for i in 6:
		var y0 := h - 4.0 - (h - 10.0) * i / 6.0
		var y1 := h - 4.0 - (h - 10.0) * (i + 1) / 6.0
		_cap(img, Vector2.ZERO, k, Vector2(cx, y0), Vector2(cx, y1), base_r * (1.0 - i * 0.12), col, false)
	if branches:
		_cap(img, Vector2.ZERO, k, Vector2(cx, h * 0.45), Vector2(w * 0.2, h * 0.18), base_r * 0.4, col, false)
		_cap(img, Vector2.ZERO, k, Vector2(cx, h * 0.38), Vector2(w * 0.82, h * 0.12), base_r * 0.4, col, false)
		_cap(img, Vector2.ZERO, k, Vector2(cx, h * 0.3), Vector2(w * 0.55, h * 0.02), base_r * 0.35, col, false)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ================================================================ 5) BRANCHES + LEAF CARDS
# The usual video-game tree: real low poly wood (trunk + main branches + forks),
# and at the end of every branch a cluster of 2-3 crossed quads ("leaf cards")
# with a twig-and-leaves texture, each turned a different way. Cards are NOT
# billboards: they're fixed geometry. Their normals are bent outward from the
# crown so the foliage is lit like a volume. Light wind sway on the cards.

const CARD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_cut = 0.45;
uniform float mip_alpha_boost = 0.5;
uniform float wind = 0.02;

void vertex() {
	// sway grows with height above the lower trunk
	float h = max(VERTEX.y - 1.5, 0.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	VERTEX.xz += vec2(sin(TIME * 1.6 + o.x * 0.3 + VERTEX.y * 0.7),
			cos(TIME * 1.3 + o.z * 0.3 + VERTEX.y * 0.6)) * wind * h;
}

void fragment() {
	vec4 c = texture(tex, UV);
	vec2 ts = vec2(textureSize(tex, 0));
	vec2 dx = dFdx(UV * ts);
	vec2 dy = dFdy(UV * ts);
	float lod = max(0.0, 0.5 * log2(max(dot(dx, dx), dot(dy, dy))));
	vec3 tint = pow(COLOR.rgb, vec3(2.2));
	ALBEDO = c.rgb * tint;
	ALPHA = c.a * (1.0 + lod * mip_alpha_boost);
	ALPHA_SCISSOR_THRESHOLD = alpha_cut;
	// Godot flips normals on back faces of double-sided meshes; undo that so
	// both sides keep the crown-outward normal from the mesh.
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	BACKLIGHT = c.rgb * tint * 0.45;
}
"""


func _build_cards(root: Node3D) -> String:
	var shader := Shader.new()
	shader.code = CARD_SHADER
	var leaf_tex := _twig_texture(int(256 * texture_scale), false)
	var needle_tex := _twig_texture(int(256 * texture_scale), true)
	var wood_mat := vertex_color_material()

	var info := PackedStringArray()
	for v in VARIANTS:
		var built: Dictionary
		match v:
			0: built = _card_tree_pine()
			1: built = _card_tree_broadleaf()
			_: built = _card_tree_poplar()
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("tex", needle_tex if v == 0 else leaf_tex)
		mat.set_shader_parameter("wind", hybrid_wind * 0.7)

		var xforms: Array[Transform3D] = []
		var colors := PackedColorArray()
		for t in trees:
			if t.variant == v:
				xforms.append(tree_transform(t))
				colors.append(t.tint)
		spawn_multimesh(root, built["wood"], xforms, colors, wood_mat)
		spawn_multimesh(root, built["leaves"], xforms, colors, mat, PackedColorArray(), true, 1.0)
		var wood_tris := int(built["wood"].surface_get_array_len(0) / 3.0)
		info.append("%d+%d" % [wood_tris, built["cards"]])
	return "Trees: %d\nwood tris + leaf cards (pine/round/poplar):\n%s" % [trees.size(), " / ".join(info)]


func _card_tree_broadleaf() -> Dictionary:
	var wood := begin_flat()
	var leaves := _begin_cards()
	var n := [0]   # card counter (array so helpers can increment it)
	var crown := Vector3(0, 3.7, 0)
	add_limb(wood, Vector3.ZERO, Vector3(0, 2.6, 0), 0.32, 0.2, 6, BARK_DARK, BARK)
	var top := Vector3(0.1, 4.4, 0.05)
	add_limb(wood, Vector3(0, 2.6, 0), top, 0.2, 0.06, 5, BARK, BARK)
	_leaf_cluster(leaves, top, Vector3.UP, 2.2, 3, crown, n)
	var branches := 5
	for i in branches:
		var yaw := TAU * i / branches + rng.randf_range(-0.3, 0.3)
		var pitch := rng.randf_range(0.6, 0.95)   # radians away from vertical
		var length := rng.randf_range(1.7, 2.3)
		var dir := Vector3(sin(pitch) * cos(yaw), cos(pitch), sin(pitch) * sin(yaw))
		var a := Vector3(0, lerpf(2.0, 3.2, float(i) / (branches - 1)) + rng.randf_range(-0.2, 0.2), 0)
		var b := a + dir * length
		add_limb(wood, a, b, 0.13, 0.05, 5, BARK, BARK)
		_leaf_cluster(leaves, b, dir, 2.0, 3, crown, n)
		# a fork from the middle of the branch
		var m := a.lerp(b, 0.55)
		var fdir := (dir + Vector3(rng.randf_range(-0.7, 0.7), 0.5, rng.randf_range(-0.7, 0.7))).normalized()
		var fb := m + fdir * rng.randf_range(0.8, 1.2)
		add_limb(wood, m, fb, 0.07, 0.03, 4, BARK, BARK)
		_leaf_cluster(leaves, fb, fdir, 1.6, 2, crown, n)
	return {"wood": finish_flat(wood), "leaves": leaves.commit(), "cards": n[0]}


func _card_tree_pine() -> Dictionary:
	var wood := begin_flat()
	var leaves := _begin_cards()
	var n := [0]
	add_limb(wood, Vector3.ZERO, Vector3(0, 6.2, 0), 0.28, 0.04, 6, BARK_DARK, BARK)
	var whorls := 6
	for w in whorls:
		var f := float(w) / (whorls - 1)
		var y := lerpf(1.3, 5.4, f)
		var length := lerpf(2.1, 0.65, f)
		var count := 5 if f < 0.7 else 4
		var off := rng.randf() * TAU
		for i in count:
			var yaw := off + TAU * i / count + rng.randf_range(-0.2, 0.2)
			var dir := Vector3(cos(yaw), rng.randf_range(-0.2, -0.05), sin(yaw)).normalized()   # slight droop
			var a := Vector3(0, y, 0)
			var b := a + dir * length
			add_limb(wood, a, b, 0.07, 0.025, 4, BARK, BARK)
			# pine cards lie ALONG the branch: one flat-ish, one upright (crossed)
			var side := dir.cross(Vector3.UP).normalized()
			var up := side.cross(dir).normalized()
			var centre := a + dir * length * 0.6
			var hw := lerpf(0.55, 0.3, f)
			var crown := Vector3(0, y + 0.7, 0)   # normals: outward + up, like a cone
			var tilt := rng.randf_range(-0.25, 0.25)
			add_card(leaves, centre, dir, (side + up * tilt).normalized(), length * 0.58, hw, crown, Color.WHITE)
			add_card(leaves, centre + up * 0.05, dir, (up - side * tilt).normalized(), length * 0.55, hw * 0.8, crown, Color.WHITE)
			n[0] += 2
	_leaf_cluster(leaves, Vector3(0, 6.0, 0), Vector3.UP, 1.1, 2, Vector3(0, 5.6, 0), n)
	return {"wood": finish_flat(wood), "leaves": leaves.commit(), "cards": n[0]}


func _card_tree_poplar() -> Dictionary:
	var wood := begin_flat()
	var leaves := _begin_cards()
	var n := [0]
	var bark := Color(0.72, 0.7, 0.65)
	add_limb(wood, Vector3.ZERO, Vector3(0, 7.6, 0), 0.22, 0.05, 6, bark.darkened(0.25), bark)
	var branches := 12
	var golden := PI * (3.0 - sqrt(5.0))
	for i in branches:
		var f := float(i) / (branches - 1)
		var yaw := golden * i * 2.0
		var pitch := rng.randf_range(0.3, 0.55)   # steep, upward branches
		var length := lerpf(1.6, 0.9, f)
		var dir := Vector3(sin(pitch) * cos(yaw), cos(pitch), sin(pitch) * sin(yaw))
		var a := Vector3(0, lerpf(1.8, 6.6, f), 0)
		var b := a + dir * length
		add_limb(wood, a, b, 0.07, 0.03, 4, bark, bark)
		_leaf_cluster(leaves, b, dir, 1.5, 3, Vector3(0, b.y - 0.4, 0), n)
	_leaf_cluster(leaves, Vector3(0, 7.6, 0), Vector3.UP, 1.6, 3, Vector3(0, 7.0, 0), n)
	return {"wood": finish_flat(wood), "leaves": leaves.commit(), "cards": n[0]}


## 2-3 crossed cards at a branch tip, rotated around the branch direction.
func _leaf_cluster(st: SurfaceTool, tip: Vector3, dir: Vector3, size: float, count: int,
		crown: Vector3, counter: Array) -> void:
	var ref := Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT
	var u := dir.cross(ref).normalized()
	var v := u.cross(dir).normalized()
	var spin := rng.randf() * PI
	for k in count:
		var ang := spin + PI * k / count + rng.randf_range(-0.2, 0.2)
		var wid := (u * cos(ang) + v * sin(ang)).normalized()
		var len_dir := (dir + Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-0.1, 0.2), rng.randf_range(-0.25, 0.25))).normalized()
		wid = (wid - len_dir * wid.dot(len_dir)).normalized()   # keep it perpendicular
		var centre := tip + len_dir * size * 0.3
		add_card(st, centre, len_dir, wid, size * 0.5, size * 0.5, crown, Color.WHITE)
	counter[0] += count


func _begin_cards() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st


## One quad. ax_len = direction from the twig's base (UV v = 1) to its tip (v = 0).
## Normals are blended toward "away from crown" so the crown reads as a volume.
static func add_card(st: SurfaceTool, centre: Vector3, ax_len: Vector3, ax_wid: Vector3,
		half_len: float, half_wid: float, crown: Vector3, col: Color, blend := 0.75) -> void:
	var card_n := ax_len.cross(ax_wid).normalized()
	var corners := [
		[centre - ax_len * half_len - ax_wid * half_wid, Vector2(0, 1)],
		[centre + ax_len * half_len - ax_wid * half_wid, Vector2(0, 0)],
		[centre + ax_len * half_len + ax_wid * half_wid, Vector2(1, 0)],
		[centre - ax_len * half_len + ax_wid * half_wid, Vector2(1, 1)],
	]
	for idx in [0, 1, 2, 0, 2, 3]:
		var p: Vector3 = corners[idx][0]
		var out := p - crown
		out = out.normalized() if out.length() > 0.001 else Vector3.UP
		var cn := card_n if card_n.dot(out) >= 0.0 else -card_n
		var ao := 0.7 + 0.3 * (out.y * 0.5 + 0.5)   # undersides darker
		var c := col * ao
		c.a = 1.0
		st.set_color(c)
		st.set_normal(cn.lerp(out, blend).normalized())
		st.set_uv(corners[idx][1])
		st.add_vertex(p)


## Low poly branch between two arbitrary points (flat shaded).
static func add_limb(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float,
		segments: int, c0: Color, c1: Color) -> void:
	var axis := (b - a).normalized()
	var ref := Vector3.UP if absf(axis.y) < 0.95 else Vector3.RIGHT
	var u := ref.cross(axis).normalized()
	var v := u.cross(axis)          # u x v = -axis, same winding as add_frustum
	var lo: Array[Vector3] = []
	var hi: Array[Vector3] = []
	for i in segments:
		var ang := TAU * i / segments
		var d := u * cos(ang) + v * sin(ang)
		lo.append(a + d * r0)
		hi.append(b + d * r1)
	for i in segments:
		var n := (i + 1) % segments
		if r1 <= 0.001:
			_tri(st, b, lo[i], lo[n], c1, c0, c0)
		else:
			_tri(st, hi[n], hi[i], lo[i], c1, c1, c0)
			_tri(st, hi[n], lo[i], lo[n], c1, c0, c0)
			_tri(st, b, hi[i], hi[n], c1, c1, c1)


## Twig texture for leaf cards: a stem from bottom-centre to the top with side
## twigs, covered in leaves (or needles). Stem base at the bottom (v = 1).
func _twig_texture(size: int, needles: bool) -> ImageTexture:
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	var base := Color(0.15, 0.33, 0.16) if needles else Color(0.3, 0.5, 0.17)
	img.fill(Color(base.r, base.g, base.b, 0.0))
	var s := float(size)
	var stem_col := Color(0.3, 0.22, 0.13)

	# stem + side twigs, as segments [a, b]
	var segs := [[Vector2(s * 0.5, s * 0.99), Vector2(s * 0.5, s * 0.06)]]
	var twigs := 4 if needles else 5
	for i in twigs:
		var t := lerpf(0.25, 0.8, float(i) / (twigs - 1))
		var a := Vector2(s * 0.5, s * (0.99 - t * 0.9))
		var side := -1.0 if i % 2 == 0 else 1.0
		var b := a + Vector2(side * s * rng.randf_range(0.26, 0.36), -s * rng.randf_range(0.12, 0.22))
		segs.append([a, b])
	for sg in segs:
		_cap(img, Vector2.ZERO, 1.0, sg[0], sg[1], maxf(1.0, s * 0.008), stem_col, false)

	# leaves / needles attached along the segments, painted dark (back) to light (front)
	var leaves := []
	var count := 520 if needles else 150
	var leaf_len := s * (0.07 if needles else 0.085)
	var leaf_w := s * (0.008 if needles else 0.04)
	for i in count:
		var sg: Array = segs[rng.randi() % segs.size()]
		var a: Vector2 = sg[0]
		var b: Vector2 = sg[1]
		var t := rng.randf_range(0.12, 1.0)
		var p := a.lerp(b, t)
		var seg_ang := (b - a).angle()
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var spread := rng.randf_range(0.6, 1.0) if needles else rng.randf_range(0.4, 1.2)
		var ang := seg_ang + side * spread
		var dirv := Vector2.from_angle(ang)
		var centre := p + dirv * leaf_len * 0.9
		var val := rng.randf_range(0.65, 1.15) + 0.15 * (1.0 - t)
		leaves.append([val, centre, ang])
	leaves.sort_custom(func(l1, l2): return l1[0] < l2[0])
	for l in leaves:
		_leaf_px(img, l[1], l[2], leaf_len, leaf_w, l[0], base)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## One leaf: an ellipse along `ang` with a lighter midrib.
func _leaf_px(img: Image, c: Vector2, ang: float, L: float, W: float, v: float, base: Color) -> void:
	var ca := cos(ang)
	var sa := sin(ang)
	var ext := int(ceil(L)) + 1
	var w := img.get_width()
	var h := img.get_height()
	for y in range(maxi(0, int(c.y) - ext), mini(h, int(c.y) + ext + 1)):
		for x in range(maxi(0, int(c.x) - ext), mini(w, int(c.x) + ext + 1)):
			var o := Vector2(x, y) - c
			var u := o.x * ca + o.y * sa
			var q := -o.x * sa + o.y * ca
			if (u / L) * (u / L) + (q / W) * (q / W) > 1.0:
				continue
			var s := v * (0.85 + 0.3 * (1.0 - absf(q) / W))
			img.set_pixel(x, y, Color(base.r * s, base.g * s, base.b * s, 1.0))


# ---------------------------------------------------------------- hair cards (mode 5 character)

## Game-style hair: a few alpha cards around the head, with a strand texture.
func _hair_cards() -> MeshInstance3D:
	var sh := Shader.new()
	sh.code = CARD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", _hair_texture(int(64 * texture_scale), int(128 * texture_scale)))
	mat.set_shader_parameter("wind", 0.0)
	mat.set_shader_parameter("alpha_cut", 0.5)

	var st := _begin_cards()
	var head := Vector3(0, 1.6, 0)
	var cards := 7
	for i in cards:
		var yaw := TAU * i / cards
		var out := Vector3(sin(yaw), 0, cos(yaw))       # yaw 0 = back of the head (+Z)
		var tangent := Vector3(cos(yaw), 0, -sin(yaw))
		var front := out.z < -0.6                         # in front of the face: short fringe only
		var ax := (Vector3.UP - out * 0.35).normalized()  # top leans in over the skull
		var half_len := 0.1 if front else 0.2
		var centre := head + out * 0.21 + Vector3(0, 0.17 if front else 0.04, 0)
		add_card(st, centre, ax, tangent, half_len, 0.17, head, Color.WHITE, 0.8)
	# a cap card across the top
	add_card(st, head + Vector3(0, 0.25, 0.03), Vector3(0, 0.2, 1).normalized(), Vector3.RIGHT, 0.26, 0.25, head, Color.WHITE, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	return mi


## Hair strands: opaque at the top, ragged tips at the bottom.
func _hair_texture(w: int, h: int, col := HAIR) -> ImageTexture:
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(col.r, col.g, col.b, 0.0))
	var strand := 0.0
	for x in w:
		if x % maxi(1, int(2 * texture_scale)) == 0:
			strand = rng.randf_range(0.7, 1.25)
		var tip := int(h * rng.randf_range(0.72, 0.98))
		for y in tip:
			var s := strand * (1.05 - 0.3 * float(y) / h)
			img.set_pixel(x, y, Color(col.r * s, col.g * s, col.b * s, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ================================================================ CHARACTER (styles)
# Same character in each style: skin head, brown hair, orange shirt,
# blue trousers, dark shoes. Built once, shown with the matching forest.

const SKIN := Color(0.95, 0.74, 0.58)
const HAIR := Color(0.3, 0.18, 0.1)
const SHIRT := Color(0.88, 0.36, 0.18)
const PANTS := Color(0.2, 0.26, 0.48)
const SHOES := Color(0.14, 0.1, 0.08)
const EYE := Color(0.06, 0.06, 0.08)


func _build_characters() -> void:
	rng.seed = random_seed + 999
	_chars[Mode.LOWPOLY] = _char_lowpoly(_lp_parts)
	_chars[Mode.BILLBOARD] = _char_sprite()
	_chars[Mode.HYBRID] = _char_hybrid()
	_chars[Mode.LAYERED] = _char_layered()
	_chars[Mode.CARDS] = _char_lowpoly(_cd_parts, true)
	for k in _chars:
		player.model.add_child(_chars[k])
		_chars[k].visible = false


func _animate_character() -> void:
	var amt := clampf(player.ground_speed / player.walk_speed, 0.0, 1.6)
	if not player.grounded:
		amt = 0.0
	var ph := player.walk_phase
	var swing := sin(ph) * amt

	match _mode:
		Mode.LOWPOLY, Mode.CARDS:
			var p: Dictionary = _lp_parts if _mode == Mode.LOWPOLY else _cd_parts
			p["leg_l"].rotation.x = swing * 0.6
			p["leg_r"].rotation.x = -swing * 0.6
			p["arm_l"].rotation.x = -swing * 0.5
			p["arm_r"].rotation.x = swing * 0.5
			p["body"].position.y = absf(sin(ph)) * 0.05 * amt
		Mode.HYBRID:
			# floating hands & feet (Rayman style) swing in 3D around the body
			for side in ["l", "r"]:
				var s := 1.0 if side == "l" else -1.0
				var foot: Node3D = _hy_parts["foot_" + side]
				var foot_rest: Vector3 = _hy_parts["foot_" + side + "_rest"]
				foot.position = foot_rest + Vector3(0, maxf(0.0, cos(ph) * s) * 0.14 * amt, -sin(ph) * s * 0.3 * amt)
				var hand: Node3D = _hy_parts["hand_" + side]
				var hand_rest: Vector3 = _hy_parts["hand_" + side + "_rest"]
				hand.position = hand_rest + Vector3(0, 0, sin(ph) * s * 0.28 * amt)
			_hy_parts["body"].position.y = absf(sin(ph)) * 0.05 * amt
		Mode.LAYERED:
			# paper-doll: flat sprite layers slide in 3D (no rotation needed)
			for side in ["l", "r"]:
				var s := 1.0 if side == "l" else -1.0
				var leg: Node3D = _ly_parts["leg_" + side]
				leg.position = _ly_parts["leg_" + side + "_rest"] \
						+ Vector3(0, maxf(0.0, cos(ph) * s) * 0.1 * amt, -sin(ph) * s * 0.28 * amt)
				var arm: Node3D = _ly_parts["arm_" + side]
				arm.position = _ly_parts["arm_" + side + "_rest"] + Vector3(0, 0, sin(ph) * s * 0.22 * amt)
			_ly_parts["body"].position.y = absf(sin(ph)) * 0.05 * amt
			var cam := player.camera.global_position
			for m in _ly_char_materials:
				m.set_shader_parameter("cam_pos", cam)
		Mode.BILLBOARD:
			# pick the sprite cell: column = view direction, row = walk frame
			var cam_pos := player.camera.global_position
			var to_cam := cam_pos - player.global_position
			to_cam.y = 0.0
			var b := player.model.global_transform.basis
			var fwd := -b.z
			fwd.y = 0.0
			var col := 2
			var flip := 0.0
			var c := fwd.normalized().dot(to_cam.normalized())
			if c > 0.707:
				col = 0          # we see the front
			elif c < -0.707:
				col = 1          # we see the back
			elif to_cam.dot(b.x) < 0.0:
				flip = 1.0       # side view, facing screen-left
			var row := 0
			if amt > 0.2:
				row = 1 + (int(ph / PI) % 2)
			_sprite_mat.set_shader_parameter("cam_pos", cam_pos)
			_sprite_mat.set_shader_parameter("cell", Vector2(col, row))
			_sprite_mat.set_shader_parameter("flip", flip)


# ---------------------------------------------------------------- 1) low poly character

## hair_cards = true: game-style hair made of alpha cards instead of a mesh blob.
func _char_lowpoly(parts: Dictionary, hair_cards := false) -> Node3D:
	var root := Node3D.new()
	var mat := vertex_color_material()
	var body := Node3D.new()
	root.add_child(body)
	parts["body"] = body

	for side in [-1.0, 1.0]:
		# leg (pivot at the hip)
		var hip := Node3D.new()
		hip.position = Vector3(0.15 * side, 0.78, 0)
		body.add_child(hip)
		var st := begin_flat()
		add_frustum(st, Vector3(0, -0.72, 0), 0.11, 0.14, 0.74, 6, PANTS.darkened(0.2), PANTS, rng, 0.05)
		add_blob(st, Vector3(0, -0.72, -0.06), Vector3(0.12, 0.07, 0.18), 6, 3, SHOES, SHOES.lightened(0.15), rng, 0.05)
		hip.add_child(_mesh_node(finish_flat(st), mat))
		parts["leg_l" if side < 0 else "leg_r"] = hip

		# arm (pivot at the shoulder)
		var shoulder := Node3D.new()
		shoulder.position = Vector3(0.44 * side, 1.26, 0)
		body.add_child(shoulder)
		st = begin_flat()
		add_frustum(st, Vector3(0, -0.56, 0), 0.07, 0.1, 0.56, 5, SHIRT.darkened(0.15), SHIRT, rng, 0.05)
		add_blob(st, Vector3(0, -0.62, 0), Vector3(0.09, 0.09, 0.09), 5, 3, SKIN.darkened(0.1), SKIN, rng, 0.05)
		shoulder.add_child(_mesh_node(finish_flat(st), mat))
		parts["arm_l" if side < 0 else "arm_r"] = shoulder

	var top := begin_flat()
	add_frustum(top, Vector3(0, 0.74, 0), 0.3, 0.38, 0.58, 7, SHIRT.darkened(0.25), SHIRT, rng, 0.04)   # torso
	add_frustum(top, Vector3(0, 1.32, 0), 0.1, 0.09, 0.1, 5, SKIN.darkened(0.1), SKIN, null)             # neck
	add_blob(top, Vector3(0, 1.58, 0), Vector3(0.25, 0.26, 0.25), 7, 5, SKIN.darkened(0.15), SKIN, rng, 0.06)  # head
	if not hair_cards:
		add_blob(top, Vector3(0, 1.68, 0.04), Vector3(0.27, 0.18, 0.27), 7, 4, HAIR, HAIR.lightened(0.1), rng, 0.08)
	for side in [-1.0, 1.0]:
		add_blob(top, Vector3(0.09 * side, 1.6, -0.22), Vector3(0.04, 0.05, 0.03), 5, 3, EYE, EYE, null)
	add_blob(top, Vector3(0, 1.53, -0.25), Vector3(0.05, 0.05, 0.06), 5, 3, SKIN.darkened(0.1), SKIN, null)  # nose
	body.add_child(_mesh_node(finish_flat(top), mat))
	if hair_cards:
		body.add_child(_hair_cards())
	return root


func _mesh_node(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	return mi


# ---------------------------------------------------------------- 2) sprite character

const SPRITE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform sampler2D tex : source_color, filter_linear, repeat_disable;
uniform vec3 cam_pos;
uniform vec2 quad_size = vec2(1.0, 2.0);
uniform vec2 grid = vec2(3.0, 3.0);   // columns = front/back/side, rows = stand/step A/step B
uniform vec2 cell = vec2(0.0);
uniform float flip = 0.0;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 to_cam = cam_pos - origin;
	to_cam.y = 0.0;
	vec3 fwd = length(to_cam) > 0.001 ? normalize(to_cam) : vec3(0.0, 0.0, 1.0);
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = cross(up, fwd);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(fwd, 0.0), vec4(origin, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(VIEW_MATRIX) * mat3(right, up, fwd);
	vec2 q = vec2(VERTEX.x / (quad_size.x * 0.5), (VERTEX.y / quad_size.y) * 2.0 - 1.0);
	NORMAL = normalize(vec3(q.x * 0.6, q.y * 0.3 + 0.2, 1.0));
}

void fragment() {
	vec2 uv = vec2(mix(UV.x, 1.0 - UV.x, flip), UV.y);
	vec4 c = texture(tex, (cell + uv) / grid);
	ALBEDO = c.rgb;
	ALPHA = c.a;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
"""


func _char_sprite() -> Node3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 2.0)
	quad.center_offset = Vector3(0, 1.0, 0)
	_sprite_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SPRITE_SHADER
	_sprite_mat.shader = sh
	_sprite_mat.set_shader_parameter("tex", _paint_character_atlas())
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = _sprite_mat
	mi.extra_cull_margin = 1.0
	return mi


## 3x3 atlas, each cell 64x128 "units" (64 units = 1 m), ground at y = 126.
## Columns: 0 front, 1 back, 2 side (facing right). Rows: 0 stand, 1 step A, 2 step B.
func _paint_character_atlas() -> ImageTexture:
	var k := 2.0 * texture_scale
	var cw := int(64 * k)
	var ch := int(128 * k)
	var img := Image.create_empty(cw * 3, ch * 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(SHIRT.r, SHIRT.g, SHIRT.b, 0.0))

	for row in 3:
		var step := 0.0 if row == 0 else (1.0 if row == 1 else -1.0)
		for col in 3:
			var o := Vector2(col * cw, row * ch)
			match col:
				0, 1:   # front / back
					var back := col == 1
					var lift_l := 6.0 if step > 0 else 0.0
					var lift_r := 6.0 if step < 0 else 0.0
					var arm_l := 80.0 - step * 4.0
					var arm_r := 80.0 + step * 4.0
					if back:   # arms behind the torso
						_cap(img, o, k, Vector2(14, 52), Vector2(12, arm_l), 5, SHIRT)
						_cap(img, o, k, Vector2(50, 52), Vector2(52, arm_r), 5, SHIRT)
					for leg in [[25.0, lift_l], [39.0, lift_r]]:
						_cap(img, o, k, Vector2(leg[0], 80), Vector2(leg[0], 116 - leg[1]), 6.5, PANTS)
						_ell(img, o, k, Vector2(leg[0], 121 - leg[1]), Vector2(7.5, 4.5), SHOES)
					_cap(img, o, k, Vector2(32, 54), Vector2(32, 78), 15, SHIRT)
					if not back:
						_cap(img, o, k, Vector2(14, 52), Vector2(12, arm_l), 5, SHIRT)
						_cap(img, o, k, Vector2(50, 52), Vector2(52, arm_r), 5, SHIRT)
					_ell(img, o, k, Vector2(12, arm_l + 4), Vector2(5, 5), SKIN)
					_ell(img, o, k, Vector2(52, arm_r + 4), Vector2(5, 5), SKIN)
					_ell(img, o, k, Vector2(32, 28), Vector2(13, 14), SKIN)
					if back:
						_ell(img, o, k, Vector2(32, 25), Vector2(14, 13), HAIR)
					else:
						_ell(img, o, k, Vector2(32, 19), Vector2(14, 8), HAIR)
						_ell(img, o, k, Vector2(27, 30), Vector2(2, 3), EYE, false)
						_ell(img, o, k, Vector2(37, 30), Vector2(2, 3), EYE, false)
				2:   # side, facing +x
					var s := step * 10.0
					_cap(img, o, k, Vector2(32, 54), Vector2(32 + s * 0.8, 80), 5, SHIRT.darkened(0.25))   # far arm
					_cap(img, o, k, Vector2(32, 80), Vector2(32 - s, 116), 6.5, PANTS.darkened(0.25))      # far leg
					_ell(img, o, k, Vector2(35 - s, 121), Vector2(8, 4.5), SHOES.darkened(0.2))
					_cap(img, o, k, Vector2(32, 80), Vector2(32 + s, 116), 6.5, PANTS)                     # near leg
					_ell(img, o, k, Vector2(35 + s, 121), Vector2(8, 4.5), SHOES)
					_cap(img, o, k, Vector2(32, 54), Vector2(32, 78), 11, SHIRT)
					_cap(img, o, k, Vector2(32, 54), Vector2(32 - s * 0.8, 80), 5, SHIRT)                  # near arm
					_ell(img, o, k, Vector2(32 - s * 0.8, 84), Vector2(5, 5), SKIN)
					_ell(img, o, k, Vector2(33, 28), Vector2(13, 14), SKIN)
					_ell(img, o, k, Vector2(46, 31), Vector2(3, 3), SKIN)                                   # nose
					_ell(img, o, k, Vector2(29, 22), Vector2(13, 10), HAIR)
					_ell(img, o, k, Vector2(40, 29), Vector2(2, 3), EYE, false)
	return ImageTexture.create_from_image(img)


## Filled ellipse with sphere-like shading and a dark outline (cartoon look).
func _ell(img: Image, o: Vector2, k: float, c: Vector2, r: Vector2, col: Color, outline := true) -> void:
	var pc := o + c * k
	var pr := r * k
	for y in range(int(pc.y - pr.y) - 1, int(pc.y + pr.y) + 2):
		for x in range(int(pc.x - pr.x) - 1, int(pc.x + pr.x) + 2):
			var d := (Vector2(x, y) - pc) / pr
			var q := d.length()
			if q > 1.0:
				continue
			_shade_px(img, x, y, col, d, q, 1.0 - 1.6 / minf(pr.x, pr.y), outline)


## Filled capsule (line segment a-b with radius r), same shading.
func _cap(img: Image, o: Vector2, k: float, a: Vector2, b: Vector2, r: float, col: Color, outline := true) -> void:
	var pa := o + a * k
	var pb := o + b * k
	var pr := r * k
	var lo := Vector2(minf(pa.x, pb.x), minf(pa.y, pb.y)) - Vector2(pr + 1, pr + 1)
	var hi := Vector2(maxf(pa.x, pb.x), maxf(pa.y, pb.y)) + Vector2(pr + 1, pr + 1)
	var ba := pb - pa
	for y in range(int(lo.y), int(hi.y) + 1):
		for x in range(int(lo.x), int(hi.x) + 1):
			var p := Vector2(x, y) - pa
			var h := clampf(p.dot(ba) / maxf(ba.dot(ba), 0.0001), 0.0, 1.0)
			var v := (p - ba * h) / pr
			var q := v.length()
			if q > 1.0:
				continue
			_shade_px(img, x, y, col, v, q, 1.0 - 1.6 / pr, outline)


func _shade_px(img: Image, x: int, y: int, col: Color, n: Vector2, q: float, edge: float, outline: bool) -> void:
	if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
		return
	var s := 1.0 + 0.3 * n.dot(Vector2(-0.7, -0.7))   # lit from top-left
	var c := col * s
	if outline and q > edge:
		c = col * 0.35
	img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))


# ---------------------------------------------------------------- 3) hybrid character

## Each part is a camera-facing quad that draws a real-looking sphere:
## per-pixel sphere normal + per-pixel DEPTH, so parts intersect and occlude
## correctly (eyes hide when seen from behind) and cast round shadows.
const SPHERE_SHADER := """
shader_type spatial;
render_mode cull_disabled;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float radius = 0.3;

void vertex() {
	// screen-aligned (in the shadow pass: light-aligned) billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1],
			INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
	vec2 d = UV * 2.0 - 1.0;
	float r2 = dot(d, d);
	if (r2 > 1.0) {
		discard;
	}
	float z = sqrt(1.0 - r2);
	NORMAL = normalize(vec3(d.x, -d.y, z));
	ALBEDO = albedo.rgb;
	ROUGHNESS = 0.75;
	vec3 p = VERTEX + vec3(0.0, 0.0, z * radius);   // point on the sphere surface
	vec4 clip = PROJECTION_MATRIX * vec4(p, 1.0);
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	DEPTH = clip.z / clip.w * 0.5 + 0.5;
#else
	DEPTH = clip.z / clip.w;
#endif
}
"""


func _char_hybrid() -> Node3D:
	var sh := Shader.new()
	sh.code = SPHERE_SHADER
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	_hy_parts["body"] = body

	# body parts (no arms/legs: floating hands & feet)
	_sphere(body, sh, Vector3(0, 0.8, 0), 0.3, PANTS)            # hips
	_sphere(body, sh, Vector3(0, 1.08, 0), 0.34, SHIRT)          # chest
	_sphere(body, sh, Vector3(0, 1.55, 0), 0.27, SKIN)           # head
	_sphere(body, sh, Vector3(0, 1.64, 0.05), 0.25, HAIR)        # hair (behind/above)
	_sphere(body, sh, Vector3(0, 1.5, -0.27), 0.06, SKIN)        # nose
	for side in [-1.0, 1.0]:
		_sphere(body, sh, Vector3(0.1 * side, 1.58, -0.23), 0.055, EYE)

	for side in ["l", "r"]:
		var s := -1.0 if side == "l" else 1.0
		var hand_rest := Vector3(0.52 * s, 0.88, 0)
		var foot_rest := Vector3(0.17 * s, 0.15, -0.03)
		_hy_parts["hand_" + side] = _sphere(root, sh, hand_rest, 0.12, SKIN)
		_hy_parts["foot_" + side] = _sphere(root, sh, foot_rest, 0.15, SHOES)
		_hy_parts["hand_" + side + "_rest"] = hand_rest
		_hy_parts["foot_" + side + "_rest"] = foot_rest
	return root


func _sphere(parent: Node3D, sh: Shader, pos: Vector3, r: float, col: Color) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(r * 2.0, r * 2.0)
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("albedo", col)
	mat.set_shader_parameter("radius", r)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.position = pos
	mi.extra_cull_margin = r
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------- 4) layered sprite character

## Paper-doll: every body part is its own flat sprite (each turns to the camera
## on its own) placed at a 3D spot around the body. Orbit and the parts
## re-stack by depth: the face sprite sits in front of the head, so it hides
## behind the head from the back and slides to the side in profile; the hair
## sprite sits behind the head and peeks out around it.
func _char_layered() -> Node3D:
	var sh := Shader.new()
	sh.code = BILLBOARD_SHADER
	var k := 2.0 * texture_scale   # 64 units = 1 m, k px per unit
	var root := Node3D.new()
	var body := Node3D.new()
	root.add_child(body)
	_ly_parts["body"] = body

	# [name, parent, size (m), centre (model space, -Z = forward)]
	var defs := [
		["hair", body, Vector2(0.58, 0.5), Vector3(0, 1.66, 0.08)],     # behind the head
		["torso", body, Vector2(0.7, 0.75), Vector3(0, 1.07, 0)],
		["head", body, Vector2(0.5, 0.52), Vector3(0, 1.6, 0)],
		["face", body, Vector2(0.3, 0.22), Vector3(0, 1.57, -0.2)],     # in front of the head
		["leg_l", root, Vector2(0.3, 0.85), Vector3(-0.14, 0.43, 0)],
		["leg_r", root, Vector2(0.3, 0.85), Vector3(0.14, 0.43, 0)],
		["arm_l", root, Vector2(0.22, 0.7), Vector3(-0.4, 1.0, 0)],
		["arm_r", root, Vector2(0.22, 0.7), Vector3(0.4, 1.0, 0)],
	]

	for d in defs:
		var size: Vector2 = d[2]
		var centre: Vector3 = d[3]
		var img := Image.create_empty(int(size.x * 64 * k), int(size.y * 64 * k), false, Image.FORMAT_RGBA8)
		img.fill(Color(0.5, 0.4, 0.3, 0.0))
		_paint_doll_part(img, d[0], k)
		img.generate_mipmaps()

		var quad := QuadMesh.new()
		quad.size = size
		quad.center_offset = Vector3(0, size.y * 0.5, 0)   # bottom pivot
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("quad_size", size)
		mat.set_shader_parameter("bulge", 0.5)
		_ly_char_materials.append(mat)

		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.position = centre - Vector3(0, size.y * 0.5, 0)
		mi.extra_cull_margin = size.x
		(d[1] as Node3D).add_child(mi)
		_ly_parts[d[0]] = mi
		_ly_parts[d[0] + "_rest"] = mi.position
	return root


## Paints one paper-doll part (coordinates in units, 64 units = 1 m).
func _paint_doll_part(img: Image, part: String, k: float) -> void:
	var o := Vector2.ZERO
	match part:
		"hair":
			_ell(img, o, k, Vector2(18.5, 16), Vector2(16.5, 14.5), HAIR)
		"torso":
			_cap(img, o, k, Vector2(22.4, 18), Vector2(22.4, 30), 17, SHIRT)
		"head":
			_ell(img, o, k, Vector2(16, 16.6), Vector2(13.5, 14.5), SKIN)
		"face":
			_ell(img, o, k, Vector2(5, 5), Vector2(2, 3), EYE, false)
			_ell(img, o, k, Vector2(14.2, 5), Vector2(2, 3), EYE, false)
			_ell(img, o, k, Vector2(9.6, 10), Vector2(2.6, 2.3), SKIN.darkened(0.1))
		"leg_l", "leg_r":
			_cap(img, o, k, Vector2(9.6, 6), Vector2(9.6, 44), 6.5, PANTS)
			_ell(img, o, k, Vector2(9.6, 48.5), Vector2(8, 4.5), SHOES)
		"arm_l", "arm_r":
			_cap(img, o, k, Vector2(7, 5.5), Vector2(7, 34), 5, SHIRT)
			_ell(img, o, k, Vector2(7, 38), Vector2(5, 5), SKIN)


# ================================================================ MONSTER (5 styles)
# A big horned, purple forest troll (~5.5 m) standing in the clearing.
# One shared 3D description (blobs + limbs per body group) drives the
# low poly, hybrid-sphere and leaf-card versions; the sprite and layered
# versions are painted from matching 2D shapes. It turns to watch you,
# breathes, and raises its arms and head to roar when you come close.

const M_SKIN := Color(0.46, 0.34, 0.6)
const M_DARK := Color(0.34, 0.24, 0.45)
const M_BELLY := Color(0.78, 0.66, 0.66)
const M_HORN := Color(0.92, 0.87, 0.72)
const M_EYE := Color(1.0, 0.85, 0.15)
const M_MOUTH := Color(0.16, 0.05, 0.08)
const M_FUR := Color(0.3, 0.2, 0.38)


func _build_monsters() -> void:
	rng.seed = random_seed + 777
	_monster_root = Node3D.new()          # home position, never moves
	_monster_root.position = monster_position
	add_child(_monster_root)
	_monster_motion = Node3D.new()        # all movement: offset, lift, yaw, spin, tilt
	_monster_root.add_child(_monster_motion)
	# moving collision: AnimatableBody3D pushes the player when the monster sweeps through
	var body := AnimatableBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.8
	cyl.height = 5.0
	cs.shape = cyl
	cs.position.y = 2.5
	body.add_child(cs)
	_monster_motion.add_child(body)

	for m in MODE_NAMES.size():
		_monster_parts[m] = {}
	_monsters[Mode.LOWPOLY] = _monster_lowpoly(_monster_parts[Mode.LOWPOLY], false)
	_monsters[Mode.BILLBOARD] = _monster_sprite(_monster_parts[Mode.BILLBOARD])
	_monsters[Mode.HYBRID] = _monster_hybrid(_monster_parts[Mode.HYBRID])
	_monsters[Mode.LAYERED] = _monster_layered(_monster_parts[Mode.LAYERED])
	_monsters[Mode.CARDS] = _monster_lowpoly(_monster_parts[Mode.CARDS], true)
	for k in _monsters:
		_monster_motion.add_child(_monsters[k])
		_monsters[k].visible = false


# ---------------------------------------------------------------- monster behaviour
# IDLE: watch the player, breathe, raise arms as they get near.
# TORNADO (when the player is within tornado_trigger m), ~4.2 s:
#   0.0-0.7  wind-up : crouch, lean back, arms pulled back, head up (roar)
#   0.7-3.4  spin    : spin ramps up to ~3 turns/s with arms straight out,
#                      body tilts and wobbles (pitch + roll precession),
#                      lifts off the ground and sweeps through the spot
#                      where the player stood, then comes back home
#   3.4-4.2  recover : spin dies down, lands with a squash, arms drop
# then a cooldown before it can attack again.

const T_WINDUP := 0.7
const T_SPIN_END := 3.4
const T_END := 4.2


func _animate_monster(delta: float) -> void:
	if _mode < 0:
		return
	var t := Time.get_ticks_msec() / 1000.0
	var to_player := player.global_position - _monster_motion.global_position
	to_player.y = 0.0
	var dist := to_player.length()
	_m_cooldown = maxf(0.0, _m_cooldown - delta)

	# pose values filled by the state, applied to whichever style is visible
	var body_y := sin(t * 1.5) * 0.06
	var head_x := sin(t * 0.9) * 0.08
	var arm_x := 0.0            # both arms forward(+)/back(-)
	var arm_swing := sin(t * 1.2) * 0.12   # opposite swing left/right (idle only)
	var arm_z := 0.0            # 0 = hanging, ~1.5 = straight out
	var lift := 0.0
	var tilt := 0.0             # radians
	var tilt_axis := Vector3.RIGHT
	var offset := Vector3.ZERO

	if not _m_attacking:
		# idle: watch the player, raise arms when they get near
		if dist > 0.1:
			_m_yaw = lerp_angle(_m_yaw, atan2(-to_player.x, -to_player.z), clampf(delta * 1.5, 0.0, 1.0))
		var near := clampf(1.0 - (dist - tornado_trigger) / 5.0, 0.0, 1.0)
		_monster_raise = lerpf(_monster_raise, near, clampf(delta * 2.0, 0.0, 1.0))
		head_x += _monster_raise * 0.35
		arm_x -= _monster_raise * 0.4
		arm_z = _monster_raise * 1.1
		if dist < tornado_trigger and _m_cooldown <= 0.0:
			_m_attacking = true
			_m_time = 0.0
			_m_spin = 0.0
			# aim at where the player stands now (home-relative), capped at 9 m
			var target := player.global_position - _monster_root.global_position
			target.y = 0.0
			_m_target = target.limit_length(9.0)
	else:
		arm_swing = 0.0
		_m_time += delta
		var tt := _m_time
		if tt < T_WINDUP:
			var e := smoothstep(0.0, 1.0, tt / T_WINDUP)
			body_y = -0.4 * e                  # crouch
			head_x = 0.45 * e                  # roar upward
			arm_x = -0.9 * e                   # arms pulled back
			arm_z = 0.6 * e
			tilt = 0.2 * e                     # lean back (around its own right axis)
			tilt_axis = Basis(Vector3.UP, _m_yaw) * Vector3.RIGHT
		elif tt < T_SPIN_END:
			var s := (tt - T_WINDUP) / (T_SPIN_END - T_WINDUP)   # 0..1 through the spin
			var ramp := smoothstep(0.0, 0.25, s) * (1.0 - smoothstep(0.8, 1.0, s))
			_m_spin += TAU * 3.0 * ramp * delta                  # up to 3 turns per second
			var arc := sin(PI * s)                                # 0 -> 1 -> 0
			lift = 1.3 * arc + 0.12 * sin(tt * 14.0) * ramp       # rise + buzzing
			tilt = 0.35 * arc                                     # lean...
			var phi := tt * 5.0                                   # ...with a precessing axis
			tilt_axis = Vector3(cos(phi), 0.0, sin(phi))          # = wobble in pitch AND roll
			offset = _m_target * arc + Vector3(cos(tt * 6.0), 0.0, sin(tt * 6.0)) * 0.9 * arc
			body_y = 0.1 * sin(tt * 20.0) * ramp
			head_x = -0.25                                        # looks down, dizzy-mad
			arm_x = 0.15 * sin(tt * 9.0)
			arm_z = lerpf(0.6, 1.5, smoothstep(0.0, 0.15, s))     # arms straight out
		elif tt < T_END:
			var e := (tt - T_SPIN_END) / (T_END - T_SPIN_END)     # 0..1
			body_y = -0.3 * sin(PI * e)                           # landing squash
			arm_z = lerpf(1.5, 0.0, e)
			head_x = lerpf(-0.25, 0.0, e)
		else:
			# done: keep the facing where the spin left it, then go back to idle
			_m_yaw = wrapf(_m_yaw + _m_spin, -PI, PI)
			_m_spin = 0.0
			_m_attacking = false
			_m_cooldown = 3.0
			_monster_raise = 0.0

	# ---- apply the whole-body motion (same for every style)
	var yaw_b := Basis(Vector3.UP, _m_yaw + _m_spin)
	var tilt_b := Basis(tilt_axis.normalized(), tilt) if absf(tilt) > 0.0001 else Basis()
	_monster_motion.transform = Transform3D(tilt_b * yaw_b, offset + Vector3(0, lift, 0))

	# ---- apply the pose to the visible style
	var p: Dictionary = _monster_parts[_mode]
	if p.has("sprite"):
		_pose_monster_sprite(p["sprite"], t, body_y, arm_z)
		return
	p["body"].position.y = body_y
	p["head"].rotation.x = head_x
	p["arm_l"].rotation = Vector3(arm_x + arm_swing, 0.0, -arm_z)
	p["arm_r"].rotation = Vector3(arm_x - arm_swing, 0.0, arm_z)


## A single sprite can't really turn or tilt, so it fakes it the classic way:
## "paper turn" (squash its width with the spin and mirror it when we'd see the
## back) and roll in the screen plane to follow the body's tilt.
func _pose_monster_sprite(spr: MeshInstance3D, t: float, body_y: float, arm_z: float) -> void:
	var mat := spr.material_override as ShaderMaterial
	var cam := player.camera
	var b := _monster_motion.global_transform.basis
	# how much of its front is facing the camera
	var to_cam := cam.global_position - _monster_motion.global_position
	to_cam.y = 0.0
	var fwd := -b.z
	fwd.y = 0.0
	var facing := fwd.normalized().dot(to_cam.normalized()) if to_cam.length() > 0.01 and fwd.length() > 0.01 else 1.0
	var width := 1.0
	var flip := 0.0
	if _m_attacking:
		width = maxf(absf(facing), 0.12)
		flip = 1.0 if facing < 0.0 else 0.0
	# body up-vector tilt, as seen from the camera, becomes an in-plane roll
	var up := b.y
	var roll := -atan2(up.dot(cam.global_transform.basis.x), up.dot(Vector3.UP))
	var breath := sin(t * 1.5)
	spr.scale = Vector3((1.0 + breath * 0.015 + arm_z * 0.06) * width,
			1.0 - breath * 0.02 + body_y * 0.25 + arm_z * 0.04, 1.0)
	mat.set_shader_parameter("roll", roll)
	mat.set_shader_parameter("flip", flip)


## Shared 3D description. Groups: [pivot, prims]; prim positions are relative
## to the group pivot. Prims: ["blob", centre, radii, colour]
## or ["limb", a, b, r0, r1, colour] (r1 = 0 makes a cone: horns, claws, teeth).
## head and arms are parented to body, so they follow its breathing.
func _monster_def() -> Dictionary:
	var arm := [
		["blob", Vector3(0, 0, 0), Vector3(0.6, 0.55, 0.6), M_SKIN],                      # shoulder
		["limb", Vector3(0, 0, 0), Vector3(-0.45, -1.2, -0.3), 0.42, 0.36, M_SKIN],         # upper arm
		["limb", Vector3(-0.45, -1.2, -0.3), Vector3(-0.55, -2.4, -0.5), 0.36, 0.3, M_SKIN],  # forearm
		["blob", Vector3(-0.55, -2.6, -0.55), Vector3(0.5, 0.45, 0.5), M_DARK],             # hand
		["limb", Vector3(-0.85, -2.85, -0.75), Vector3(-0.95, -3.25, -0.95), 0.09, 0.0, M_HORN],
		["limb", Vector3(-0.55, -2.95, -0.85), Vector3(-0.58, -3.3, -1.1), 0.09, 0.0, M_HORN],
		["limb", Vector3(-0.25, -2.85, -0.75), Vector3(-0.2, -3.25, -0.95), 0.09, 0.0, M_HORN],
	]
	var leg := [
		["limb", Vector3(-0.8, 0.25, 0.05), Vector3(-0.8, 1.6, 0.05), 0.5, 0.6, M_SKIN],
		["blob", Vector3(-0.85, 0.28, -0.25), Vector3(0.6, 0.3, 0.75), M_DARK],
	]
	return {
		"legs": [Vector3.ZERO, leg + _mirror_prims(leg)],
		"body": [Vector3.ZERO, [
			["blob", Vector3(0, 2.6, 0.1), Vector3(1.6, 1.45, 1.3), M_SKIN],
			["blob", Vector3(0, 2.3, -0.55), Vector3(1.1, 1.0, 0.8), M_BELLY],
			["blob", Vector3(0, 3.5, 0.4), Vector3(1.25, 0.65, 0.9), M_SKIN],     # hunched back
		]],
		"head": [Vector3(0, 3.7, -0.3), [
			["blob", Vector3(0, 0.5, -0.15), Vector3(0.85, 0.72, 0.8), M_SKIN],
			["blob", Vector3(0, 0.2, -0.6), Vector3(0.6, 0.35, 0.45), M_SKIN],     # snout / jaw
			["limb", Vector3(-0.5, 0.95, -0.1), Vector3(-1.05, 1.65, 0.15), 0.2, 0.0, M_HORN],
			["limb", Vector3(0.5, 0.95, -0.1), Vector3(1.05, 1.65, 0.15), 0.2, 0.0, M_HORN],
			["blob", Vector3(-0.32, 0.62, -0.9), Vector3(0.14, 0.14, 0.08), M_EYE],
			["blob", Vector3(0.32, 0.62, -0.9), Vector3(0.14, 0.14, 0.08), M_EYE],
			["blob", Vector3(0, 0.12, -1.0), Vector3(0.4, 0.08, 0.08), M_MOUTH],
			["limb", Vector3(-0.22, 0.2, -1.03), Vector3(-0.22, -0.02, -1.05), 0.06, 0.0, M_HORN],
			["limb", Vector3(0.22, 0.2, -1.03), Vector3(0.22, -0.02, -1.05), 0.06, 0.0, M_HORN],
		]],
		"arm_l": [Vector3(-1.55, 3.4, 0), arm],
		"arm_r": [Vector3(1.55, 3.4, 0), _mirror_prims(arm)],
	}


func _mirror_prims(prims: Array) -> Array:
	var out := []
	var flip := Vector3(-1, 1, 1)
	for p in prims:
		var q: Array = p.duplicate()
		q[1] = (p[1] as Vector3) * flip
		if q[0] == "limb":
			q[2] = (p[2] as Vector3) * flip
		out.append(q)
	return out


## Creates the group pivot node (head/arms go under body) and records it.
func _monster_group(root: Node3D, parts: Dictionary, group: String, pivot: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pivot
	var parent: Node3D = root if (group == "legs" or group == "body") else parts["body"]
	parent.add_child(n)
	parts[group] = n
	return n


# ---------------------------------------------------------------- 1 & 5) low poly (+ fur cards)

func _monster_lowpoly(parts: Dictionary, fur: bool) -> Node3D:
	var root := Node3D.new()
	var mat := vertex_color_material()
	var def := _monster_def()
	for group in def:
		var node := _monster_group(root, parts, group, def[group][0])
		var st := begin_flat()
		for prim in def[group][1]:
			var col: Color = prim[3] if prim[0] == "blob" else prim[5]
			if prim[0] == "blob":
				var radii: Vector3 = prim[2]
				var big := maxf(radii.x, maxf(radii.y, radii.z)) > 0.4
				add_blob(st, prim[1], radii, 9 if big else 6, 6 if big else 4,
						col.darkened(0.25), col, rng, 0.07 if big else 0.0)
			else:
				var r0: float = prim[3]
				add_limb(st, prim[1], prim[2], r0, prim[4], 7 if r0 > 0.2 else 5, col.darkened(0.15), col)
		node.add_child(_mesh_node(finish_flat(st), mat))
	if fur:
		_monster_fur(parts)
	return root


## Game-style fur: alpha cards as a mane over the shoulders/back, a tuft on the
## head and on each shoulder (cards are parented so they move with the parts).
func _monster_fur(parts: Dictionary) -> void:
	var sh := Shader.new()
	sh.code = CARD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", _hair_texture(int(64 * texture_scale), int(128 * texture_scale), M_FUR))
	mat.set_shader_parameter("wind", 0.0)
	mat.set_shader_parameter("alpha_cut", 0.5)

	# mane: ring of hanging cards around the hunched shoulders, thicker at the back
	var st := _begin_cards()
	var centre := Vector3(0, 3.0, 0.2)
	for i in 14:
		var yaw := TAU * i / 14.0
		var out := Vector3(sin(yaw), 0, cos(yaw))
		if out.z < -0.5:
			continue   # leave the chest/face side open
		var tangent := Vector3(cos(yaw), 0, -sin(yaw))
		var ax := (Vector3.UP - out * 0.45).normalized()
		var pos := Vector3(0, 3.65, 0.35) + out * Vector3(1.15, 0, 0.9) + Vector3(0, rng.randf_range(-0.1, 0.1), 0)
		add_card(st, pos, ax, tangent, 0.55, 0.5, centre, Color.WHITE, 0.8)
	# second, lower row down the back
	for i in 5:
		var x := lerpf(-0.9, 0.9, i / 4.0)
		var pos := Vector3(x, 2.75, 1.25)
		add_card(st, pos, (Vector3.UP - Vector3.BACK * 0.3).normalized(), Vector3.RIGHT, 0.55, 0.45, centre, Color.WHITE, 0.8)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	(parts["body"] as Node3D).add_child(mi)

	# head tuft (in head-pivot space)
	st = _begin_cards()
	for i in 4:
		var yaw := TAU * i / 4.0 + 0.4
		var out := Vector3(sin(yaw), 0, cos(yaw))
		add_card(st, Vector3(0, 1.15, 0.05) + out * 0.25, (Vector3.UP - out * 0.5).normalized(),
				Vector3(cos(yaw), 0, -sin(yaw)), 0.3, 0.3, Vector3(0, 0.5, -0.15), Color.WHITE, 0.8)
	mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	(parts["head"] as Node3D).add_child(mi)

	# shoulder tufts (in arm-pivot space)
	for side in ["arm_l", "arm_r"]:
		st = _begin_cards()
		var sx := -1.0 if side == "arm_l" else 1.0
		for i in 3:
			var yaw := TAU * i / 3.0
			var out := Vector3(sin(yaw) * 0.7 + sx * 0.7, 0, cos(yaw) * 0.7).normalized()
			add_card(st, Vector3(0, 0.45, 0) + out * 0.35, (Vector3.UP - out * 0.6).normalized(),
					Vector3(out.z, 0, -out.x), 0.35, 0.35, Vector3.ZERO, Color.WHITE, 0.8)
		mi = MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = mat
		(parts[side] as Node3D).add_child(mi)


# ---------------------------------------------------------------- 3) hybrid: sphere impostors

func _monster_hybrid(parts: Dictionary) -> Node3D:
	var sh := Shader.new()
	sh.code = SPHERE_SHADER
	var root := Node3D.new()
	var def := _monster_def()
	for group in def:
		var node := _monster_group(root, parts, group, def[group][0])
		for prim in def[group][1]:
			for sp in _prim_to_spheres(prim):
				_sphere(node, sh, sp[0], sp[1], sp[2])
	return root


## Approximates a blob or limb with one or a few spheres: [position, radius, colour].
func _prim_to_spheres(prim: Array) -> Array:
	var out := []
	if prim[0] == "blob":
		var c: Vector3 = prim[1]
		var r: Vector3 = prim[2]
		var col: Color = prim[3]
		var mx := maxf(r.x, maxf(r.y, r.z))
		var mn := minf(r.x, minf(r.y, r.z))
		if mx / mn < 1.6:
			out.append([c, (r.x + r.y + r.z) / 3.0, col])
		else:
			# stretched blob: a short chain of spheres along its long axis
			var axis := Vector3.RIGHT if mx == r.x else (Vector3.UP if mx == r.y else Vector3.BACK)
			var rad := ((r.x + r.y + r.z) - mx) * 0.5 * 1.1
			var n := clampi(int(ceil(mx / rad)) + 1, 2, 5)
			for i in n:
				var f := float(i) / (n - 1) * 2.0 - 1.0
				out.append([c + axis * f * maxf(mx - rad, 0.0), rad, col])
	else:
		var a: Vector3 = prim[1]
		var b: Vector3 = prim[2]
		var r0: float = prim[3]
		var r1: float = prim[4]
		var col: Color = prim[5]
		if r1 < 0.01:
			r1 = r0 * 0.3   # cones end in a small ball
		var n := clampi(int(ceil(a.distance_to(b) / ((r0 + r1) * 0.5))) + 1, 2, 3 if r0 < 0.12 else 6)
		for i in n:
			var f := float(i) / (n - 1)
			out.append([a.lerp(b, f), lerpf(r0, r1, f), col])
	return out


# ---------------------------------------------------------------- 2) single sprite

const M_SPRITE_SIZE := Vector2(5.6, 6.0)   # metres covered by the one sprite (x: -2.8..2.8, y: 0..6)


func _monster_sprite(parts: Dictionary) -> Node3D:
	var k := texture_scale
	var ppm := 64.0 * k   # pixels per metre
	var img := Image.create_empty(int(M_SPRITE_SIZE.x * ppm), int(M_SPRITE_SIZE.y * ppm), false, Image.FORMAT_RGBA8)
	img.fill(Color(M_SKIN.r, M_SKIN.g, M_SKIN.b, 0.0))
	# paint the same parts as the layered version, flattened, back to front
	for part in ["leg_l", "leg_r", "horn_l", "horn_r", "body", "arm_l", "arm_r", "belly", "head", "face"]:
		var info: Array = _monster_layer_info(part)
		var size: Vector2 = info[1]
		var world_c: Vector3 = _monster_group_pivot(info[0]) + (info[2] as Vector3)
		# seen from the front: the monster's +X (its right) is on the image's left
		var o := Vector2((-world_c.x - size.x * 0.5 + M_SPRITE_SIZE.x * 0.5) * ppm,
				(M_SPRITE_SIZE.y - (world_c.y + size.y * 0.5)) * ppm)
		_paint_monster_part(img, part, o, k)
	img.generate_mipmaps()

	var quad := QuadMesh.new()
	quad.size = M_SPRITE_SIZE
	quad.center_offset = Vector3(0, M_SPRITE_SIZE.y * 0.5, 0)
	var sh := Shader.new()
	sh.code = BILLBOARD_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("quad_size", M_SPRITE_SIZE)
	mat.set_shader_parameter("bulge", 0.5)
	_monster_cam_materials.append(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	mi.extra_cull_margin = M_SPRITE_SIZE.x
	var root := Node3D.new()
	root.add_child(mi)
	parts["sprite"] = mi
	return root


# ---------------------------------------------------------------- 4) layered sprites (paper doll)

## [group, size (m), centre relative to the group pivot]
func _monster_layer_info(part: String) -> Array:
	match part:
		"leg_l": return ["legs", Vector2(1.3, 1.7), Vector3(-0.8, 0.85, 0.1)]
		"leg_r": return ["legs", Vector2(1.3, 1.7), Vector3(0.8, 0.85, 0.1)]
		"body": return ["body", Vector2(3.4, 3.2), Vector3(0, 2.6, 0.15)]
		"belly": return ["body", Vector2(2.3, 2.1), Vector3(0, 2.3, -0.65)]
		"head": return ["head", Vector2(1.9, 1.7), Vector3(0, 0.5, -0.15)]
		"horn_l": return ["head", Vector2(0.8, 1.0), Vector3(-0.75, 1.3, 0.0)]
		"horn_r": return ["head", Vector2(0.8, 1.0), Vector3(0.75, 1.3, 0.0)]
		"face": return ["head", Vector2(1.3, 1.0), Vector3(0, 0.35, -0.95)]
		"arm_l": return ["arm_l", Vector2(1.0, 3.4), Vector3(-0.3, -1.6, -0.3)]
		"arm_r": return ["arm_r", Vector2(1.0, 3.4), Vector3(0.3, -1.6, -0.3)]
	return []


func _monster_group_pivot(group: String) -> Vector3:
	return (_monster_def()[group][0]) as Vector3


func _monster_layered(parts: Dictionary) -> Node3D:
	var sh := Shader.new()
	sh.code = BILLBOARD_SHADER
	var k := texture_scale
	var root := Node3D.new()
	var def := _monster_def()
	for group in def:
		_monster_group(root, parts, group, def[group][0])
	for part in ["leg_l", "leg_r", "body", "belly", "head", "horn_l", "horn_r", "face", "arm_l", "arm_r"]:
		var info: Array = _monster_layer_info(part)
		var size: Vector2 = info[1]
		var centre: Vector3 = info[2]
		var img := Image.create_empty(int(size.x * 64 * k), int(size.y * 64 * k), false, Image.FORMAT_RGBA8)
		img.fill(Color(M_SKIN.r, M_SKIN.g, M_SKIN.b, 0.0))
		_paint_monster_part(img, part, Vector2.ZERO, k)
		img.generate_mipmaps()

		var quad := QuadMesh.new()
		quad.size = size
		quad.center_offset = Vector3(0, size.y * 0.5, 0)   # bottom pivot
		var mat := ShaderMaterial.new()
		mat.shader = sh
		mat.set_shader_parameter("tex", ImageTexture.create_from_image(img))
		mat.set_shader_parameter("quad_size", size)
		mat.set_shader_parameter("bulge", 0.6)
		_monster_cam_materials.append(mat)
		var mi := MeshInstance3D.new()
		mi.mesh = quad
		mi.material_override = mat
		mi.position = centre - Vector3(0, size.y * 0.5, 0)
		mi.extra_cull_margin = size.x
		(parts[info[0]] as Node3D).add_child(mi)
	return root


## Paints one monster part. Coordinates are in units of 1/64 m inside the
## part's own image; o = pixel offset (used to paint all parts into one sprite).
func _paint_monster_part(img: Image, part: String, o: Vector2, k: float) -> void:
	match part:
		"leg_l", "leg_r":
			_cap(img, o, k, Vector2(41.6, 22), Vector2(41.6, 78), 28, M_SKIN)
			_ell(img, o, k, Vector2(41.6, 92), Vector2(38, 13), M_DARK)
		"body":
			_ell(img, o, k, Vector2(108.8, 102.4), Vector2(104, 98), M_SKIN)
			for spot in [[Vector2(55, 55), Vector2(11, 8)], [Vector2(160, 70), Vector2(15, 10)],
					[Vector2(70, 155), Vector2(10, 7)], [Vector2(150, 150), Vector2(8, 6)]]:
				_ell(img, o, k, spot[0], spot[1], M_DARK, false)
		"belly":
			_ell(img, o, k, Vector2(73.6, 67.2), Vector2(68, 62), M_BELLY)
		"head":
			_ell(img, o, k, Vector2(60.8, 54.4), Vector2(56, 50), M_SKIN)
		"face":
			for ex in [22.0, 61.2]:
				_ell(img, o, k, Vector2(ex, 16), Vector2(10, 10), M_EYE)
				_ell(img, o, k, Vector2(ex, 17), Vector2(3, 7), EYE, false)
			_ell(img, o, k, Vector2(41.6, 44), Vector2(30, 10), M_MOUTH)
			_ell(img, o, k, Vector2(28, 40), Vector2(3.5, 6), M_HORN)
			_ell(img, o, k, Vector2(55.2, 40), Vector2(3.5, 6), M_HORN)
		"horn_l", "horn_r":
			var w := 51.2
			# from the front, the left horn (-X) is on screen-right: its tip points right
			var fx := func(x: float) -> float: return x if part == "horn_r" else w - x
			_cap(img, o, k, Vector2(fx.call(40.0), 60), Vector2(fx.call(26.0), 32), 10, M_HORN)
			_cap(img, o, k, Vector2(fx.call(26.0), 32), Vector2(fx.call(12.0), 7), 6, M_HORN)
		"arm_l", "arm_r":
			_cap(img, o, k, Vector2(32, 10), Vector2(34, 120), 22, M_SKIN)
			_ell(img, o, k, Vector2(34, 160), Vector2(28, 28), M_DARK)
			for cx in [16.0, 34.0, 52.0]:
				_ell(img, o, k, Vector2(cx, 194 if cx != 34.0 else 198), Vector2(5, 9), M_HORN)


# ================================================================ helpers

## Splits instances into MultiMesh chunks so frustum culling still works.
## extra_margin: billboards rotate in the shader, so widen their bounding box.
func spawn_multimesh(parent: Node3D, mesh: Mesh, xforms: Array[Transform3D], colors: PackedColorArray,
		material: Material, customs := PackedColorArray(), cast_shadow := true,
		extra_margin := 0.0) -> void:
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
		parent.add_child(mmi)


func tree_transform(t: TreeData) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, t.yaw).scaled(Vector3.ONE * t.scale), t.position)


## Low-poly frustum/cone (r_top = 0 gives a cone), flat-shaded triangles.
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


## Low-poly lumpy sphere/ellipsoid.
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


static func begin_flat() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)   # -1 = flat normals
	return st


static func finish_flat(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


static func vertex_color_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.95
	return m


# ================================================================ PLAYER (inner class)

class Player extends CharacterBody3D:
	var walk_speed := 5.0
	var sprint_speed := 11.0
	var jump_velocity := 5.5
	var acceleration := 12.0
	var turn_speed := 10.0
	var mouse_sensitivity := 0.0025
	var camera_distance := 5.0
	var min_zoom := 1.5
	var max_zoom := 14.0
	var min_pitch_deg := -75.0
	var max_pitch_deg := 35.0

	var camera: Camera3D
	var model: Node3D
	var walk_phase := 0.0      # advances with distance walked (for animation)
	var ground_speed := 0.0
	var grounded := true
	var _pivot: Node3D
	var _spring: SpringArm3D
	var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var _pitch := deg_to_rad(-20.0)
	var _spawn := Vector3.ZERO

	func _ready() -> void:
		_spawn = global_position
		# collision
		var col := CollisionShape3D.new()
		var cap := CapsuleShape3D.new()
		cap.radius = 0.4
		cap.height = 1.8
		col.shape = cap
		col.position.y = 0.9
		add_child(col)
		# visual model root (turns independently of the camera, -Z = forward).
		# The three character styles are added under it by the main script.
		model = Node3D.new()
		add_child(model)
		# camera rig
		_pivot = Node3D.new()
		_pivot.position = Vector3(0, 1.6, 0)
		add_child(_pivot)
		_spring = SpringArm3D.new()
		_spring.spring_length = camera_distance
		_spring.margin = 0.2
		var s := SphereShape3D.new()
		s.radius = 0.25
		_spring.shape = s
		_spring.add_excluded_object(get_rid())
		_spring.rotation.x = _pitch
		_pivot.add_child(_spring)
		camera = Camera3D.new()
		camera.fov = 70.0
		camera.far = 500.0
		_spring.add_child(camera)
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
			_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity,
					deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))
			_spring.rotation.x = _pitch
		elif event is InputEventMouseButton and event.pressed:
			match event.button_index:
				MOUSE_BUTTON_WHEEL_UP:
					camera_distance = maxf(min_zoom, camera_distance - 0.5)
				MOUSE_BUTTON_WHEEL_DOWN:
					camera_distance = minf(max_zoom, camera_distance + 0.5)
				_:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	func _key(k: Key) -> float:
		return 1.0 if Input.is_physical_key_pressed(k) else 0.0

	func _physics_process(delta: float) -> void:
		if not is_on_floor():
			velocity.y -= _gravity * delta
		elif Input.is_physical_key_pressed(KEY_SPACE):
			velocity.y = jump_velocity

		var right_in := maxf(_key(KEY_D), _key(KEY_RIGHT)) - maxf(_key(KEY_A), _key(KEY_LEFT))
		var fwd_in := maxf(_key(KEY_W), _key(KEY_UP)) - maxf(_key(KEY_S), _key(KEY_DOWN))
		var cam_basis := _pivot.global_transform.basis
		var forward := -cam_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		var right := cam_basis.x
		right.y = 0.0
		right = right.normalized()
		var dir := right * right_in + forward * fwd_in
		if dir.length_squared() > 1.0:
			dir = dir.normalized()

		var speed := sprint_speed if Input.is_physical_key_pressed(KEY_SHIFT) else walk_speed
		var t := clampf(acceleration * delta, 0.0, 1.0)
		velocity.x = lerpf(velocity.x, dir.x * speed, t)
		velocity.z = lerpf(velocity.z, dir.z * speed, t)
		if dir.length_squared() > 0.001:
			model.rotation.y = lerp_angle(model.rotation.y, atan2(-dir.x, -dir.z),
					clampf(turn_speed * delta, 0.0, 1.0))
		move_and_slide()
		grounded = is_on_floor()
		ground_speed = Vector2(velocity.x, velocity.z).length()
		walk_phase = fmod(walk_phase + ground_speed * delta * 2.4, TAU * 100.0)

		if global_position.y < -30.0:
			global_position = _spawn
			velocity = Vector3.ZERO

	func _process(delta: float) -> void:
		_spring.spring_length = lerpf(_spring.spring_length, camera_distance, clampf(10.0 * delta, 0.0, 1.0))
