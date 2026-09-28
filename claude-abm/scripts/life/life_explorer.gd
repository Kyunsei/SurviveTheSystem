extends Node3D
## 3D view of the unified-life simulation: walk among the organisms. Mobile
## organisms are creatures (coloured by lifestyle: green = sunlight, yellow =
## plants, red = meat, bluish = brain; meat-eaters grow horns). Sessile ones are
## grass, flowers, bushes or trees by size; those with a mouth show red jaws,
## those without leaves are pale like fungi. The GPU writes all of it into
## MultiMesh buffers; the CPU only moves the player.
##
## Tab: 2D map. Esc: menu. P: pause. [ ]: speed. Reads --bench=SECONDS
## (prints fps, saves a screenshot) and --overview=DIST (high camera).

const Player := preload("res://scripts/player.gd")
const TERRAIN_SIZE := 1536.0
const TERRAIN_SPACING := 3.0

var sim: Node
var player: Node3D
var _world := 1024
var _cell := 8.0
var _world_m := 8192.0
var _heights := PackedFloat32Array()
var _mats := {}
var _terrain: MeshInstance3D
var _water: MeshInstance3D
var _hud: Label
var _help: Label
var _last_stats := {}
var _bench_seconds := 0.0
var _bench_time := 0.0


func _ready() -> void:
	sim = Launch.get_life()
	sim.active = true
	sim.explorer = true
	if Launch.sim != null: # the other simulation waits while this one runs
		Launch.sim.set_meta("was_paused", Launch.sim.paused)
		Launch.sim.paused = true
	_world = sim.world_size
	_cell = sim.cell_size
	_world_m = _world * _cell
	_bench_seconds = float(Launch.args.get("bench", 0.0))

	_setup_environment()
	_setup_meshes()
	player = Player.new()
	player.world_size = _world_m
	add_child(player)
	_setup_hud()

	sim.heightmap_ready.connect(_on_heightmap)
	sim.stats_updated.connect(func(s: Dictionary) -> void: _last_stats = s)
	sim.restarted.connect(func() -> void: _heights = PackedFloat32Array())
	if not sim.heights.is_empty():
		_on_heightmap.call_deferred(sim.heights)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if Launch.args.has("overview"):
		player.set("_orbit", float(Launch.args.overview))
		player.pitch = -0.45
	if _bench_seconds > 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _exit_tree() -> void:
	sim.active = false
	sim.explorer = false
	if Launch.sim != null:
		Launch.sim.paused = Launch.sim.get_meta("was_paused", false)


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_horizon_color = Color(0.66, 0.74, 0.82)
	sky_mat.ground_horizon_color = Color(0.66, 0.74, 0.82)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.66, 0.74, 0.82)
	env.fog_density = 0.0016
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


func _setup_meshes() -> void:
	for n in ["terrain", "water", "organism"]:
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/%s.gdshader" % n)
		m.set_shader_parameter("world_size", _world_m)
		_mats[n] = m
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * TERRAIN_SIZE
	plane.subdivide_width = int(TERRAIN_SIZE / TERRAIN_SPACING) - 1
	plane.subdivide_depth = plane.subdivide_width
	_terrain = MeshInstance3D.new()
	_terrain.mesh = plane
	_terrain.material_override = _mats.terrain
	_terrain.extra_cull_margin = 200.0
	_terrain.visible = false
	add_child(_terrain)
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2.ONE * TERRAIN_SIZE
	_water = MeshInstance3D.new()
	_water.mesh = water_plane
	_water.material_override = _mats.water
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_water.visible = false
	add_child(_water)
	# Every organism is the same body rig, shaped per instance by its developed body.
	for mm in [sim.sessile_multimesh, sim.creature_multimesh]:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mats.organism
		add_child(mmi)


func _setup_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(12, 12)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.75)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	_hud = Label.new()
	_hud.add_theme_font_size_override("font_size", 13)
	panel.add_child(_hud)
	_help = Label.new()
	_help.add_theme_font_size_override("font_size", 13)
	_help.text = "WASD move   Shift sprint   Space jump   Mouse look   V first/third person   P pause   [ ] sim speed   Tab 2D map   Esc menu"
	_help.anchor_top = 1.0
	_help.anchor_bottom = 1.0
	_help.offset_top = -30
	_help.offset_left = 12
	layer.add_child(_help)


func _on_heightmap(heights: PackedFloat32Array) -> void:
	var first := _heights.is_empty()
	_heights = heights
	var img := Image.create_from_data(_world, _world, false, Image.FORMAT_RF, heights.to_byte_array())
	img.convert(Image.FORMAT_RH)
	var tex := ImageTexture.create_from_image(img)
	for m in _mats.values():
		m.set_shader_parameter("height_tex", tex)
		m.set_shader_parameter("field_tex", sim.texture)
	_terrain.visible = true
	_water.visible = true
	player.height_at = height_at
	if first:
		if Launch.focus_m.x >= 0.0:
			player.spawn(_land_near(Launch.focus_m))
			Launch.focus_m = Vector2(-1, -1)
		else:
			player.spawn(_land_near(Vector2(_world_m, _world_m) * 0.5))


func _process(delta: float) -> void:
	if _heights.is_empty():
		return
	var p: Vector3 = player.position
	sim.viewer_pos = Vector2(fposmod(p.x, _world_m), fposmod(p.z, _world_m)) / _cell
	var snap := Vector3(snappedf(p.x, TERRAIN_SPACING * 2.0), 0, snappedf(p.z, TERRAIN_SPACING * 2.0))
	_terrain.position = snap
	_water.position = snap
	_update_hud()
	if Launch.args.has("seekmobile") and _bench_time > 3.0 and not has_meta("sought"): # dev
		set_meta("sought", true)
		sim.find_mobile(func(p: Vector2) -> void:
			player.spawn(Vector3(p.x + 6.0, height_at(p.x + 6.0, p.y + 6.0), p.y + 6.0)))
	if _bench_seconds > 0.0:
		_bench_time += delta
		if _bench_time >= _bench_seconds:
			_bench_seconds = 0.0
			print("life3D fps=%d tick=%d mobile drawn=%d sessile drawn=%d" % [Engine.get_frames_per_second(), sim.tick,
					sim.creature_multimesh.visible_instance_count, sim.sessile_multimesh.visible_instance_count])
			var path := OS.get_user_data_dir().path_join("life3d.png")
			get_viewport().get_texture().get_image().save_png(path)
			print("screenshot: ", path)
			get_tree().quit()


func _update_hud() -> void:
	var s := _last_stats
	var lines := ["Unified life   %s%.0f ticks/s   %d fps" % ["PAUSED   " if sim.paused else "", sim.ticks_per_second, Engine.get_frames_per_second()]]
	if not s.is_empty():
		lines.append("Tick %d   generation %d   organisms %s" % [s.tick, s.max_generation, _fmt(s.organisms)])
		lines.append("Sessile %s (mouths %s)   mobile %s: plant-eaters %s, meat-eaters %s" % [
				_fmt(s.sessile), _fmt(s.sessile_mouth), _fmt(s.mobile), _fmt(s.mobile_plant_eaters), _fmt(s.mobile_carnivores)])
		lines.append("Eyes %s   brains %s (%.1f neurons)   mobile with leaves %s" % [
				_fmt(s.with_eyes), _fmt(s.with_brain), s.avg_neurons, _fmt(s.mobile_with_leaves)])
	_hud.text = "\n".join(lines)


static func _fmt(n: int) -> String:
	if n >= 1_000_000:
		return "%.2fM" % (n / 1_000_000.0)
	if n >= 1000:
		return "%.1fk" % (n / 1000.0)
	return str(n)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE: Launch.go(Launch.MENU)
			KEY_TAB: Launch.switch_view(Launch.VIEW_LIFE, Vector2(player.position.x, player.position.z))
			KEY_P: sim.paused = not sim.paused
			KEY_BRACKETLEFT: sim.ticks_per_second = maxf(sim.ticks_per_second / 1.5, 1.0)
			KEY_BRACKETRIGHT: sim.ticks_per_second = minf(sim.ticks_per_second * 1.5, 60.0)


## Bilinear terrain height (m) at world x, z (metres).
func height_at(x: float, z: float) -> float:
	if _heights.is_empty():
		return 0.0
	var fx := x / _cell - 0.5
	var fz := z / _cell - 0.5
	var ix := floori(fx)
	var iz := floori(fz)
	var tx := fx - ix
	var tz := fz - iz
	var w := _world
	var x0 := posmod(ix, w)
	var x1 := posmod(ix + 1, w)
	var z0 := posmod(iz, w) * w
	var z1 := posmod(iz + 1, w) * w
	return lerpf(lerpf(_heights[z0 + x0], _heights[z0 + x1], tx),
			lerpf(_heights[z1 + x0], _heights[z1 + x1], tx), tz)


func _land_near(p: Vector2) -> Vector3:
	for r in range(0, 3000, 20):
		for k in maxi(1, r / 10):
			var a := TAU * k / maxi(1, r / 10)
			var x := fposmod(p.x + cos(a) * r, _world_m)
			var z := fposmod(p.y + sin(a) * r, _world_m)
			var h := height_at(x, z)
			if h > 0.5:
				return Vector3(x, h, z)
	return Vector3(p.x, 10.0, p.y)
