extends Node3D
## 3D explorer: walk the same GPU ecosystem as the 2D view.
##
## The simulation writes the creatures around the player straight into a
## MultiMesh buffer (no CPU work per agent). The CPU only receives a short list
## of nearby agents for picking, the agent being inspected, and the damage the
## player took. The player is visible to agents (as a predator, a lure or prey)
## and can strike, feed, breed or follow them.
##
## Command line (besides Launch's): --bench=SECONDS prints fps and saves a
## screenshot, --profile=1 prints GPU timings, --seektree=1 moves the player next
## to the nearest inland tree after 3 s (to check woodland visuals).

const Simulation := preload("res://scripts/simulation.gd")
const Player := preload("res://scripts/player.gd")
const Hud := preload("res://scripts/hud.gd")
const Meshes := preload("res://scripts/meshes.gd")

const TERRAIN_SIZE := 1536.0
const TERRAIN_SPACING := 3.0
const REACH := 6.0 ## strike / feed distance
const BREED_REACH := 20.0
const PICK_RANGE := 60.0
enum Presence { INVISIBLE, PREDATOR, LURE, PREY }
const PRESENCE_NAMES := ["invisible", "predator (they flee)", "lure (its species follows you)", "prey (predators hunt you)"]

var sim: Node
var player: Node3D
var hud: CanvasLayer
var ticks_per_second := 10.0
var presence := Presence.INVISIBLE

var _world := 2048 ## cells per side
var _cell := 16.0 ## metres per cell
var _world_m := 32768.0 ## metres per side
var _heights := PackedFloat32Array()
var _height_tex: ImageTexture
var _terrain: MeshInstance3D
var _water: MeshInstance3D
var _plants: Array[MultiMeshInstance3D] = [] ## grass, flowers, bushes, trees (GPU-filled)
var _agents: MultiMeshInstance3D
var _mats := {}
var _phase_acc := 0.0
var _near: Array[Dictionary] = []
var _aimed := {} ## near-list entry under the crosshair
var _inspected := {}
var _lure_pheno := 0
var _tracking := false
var _track_confirmed := false ## the GPU has picked up the TRACK command
var _last_damage := -1
var _health := 100.0
var _bench_seconds := 0.0
var _grass_hidden := false
var _terrain_hidden := false
var _trees_hidden := false
var _sun: DirectionalLight3D
var _bench_time := 0.0


func _ready() -> void:
	sim = Launch.get_sim()
	sim.set_view(true) # spread each tick over several frames, creatures in 3D
	sim.profile = Launch.args.get("profile", "0") == "1"
	_bench_seconds = float(Launch.args.get("bench", 0.0))
	_world = sim.world_size
	_cell = sim.cell_size
	_world_m = _world * _cell

	_setup_environment()
	_setup_world_meshes()

	player = Player.new()
	player.world_size = _world_m
	add_child(player)
	hud = Hud.new()
	hud.explorer = self
	add_child(hud)

	sim.heightmap_ready.connect(_on_heightmap)
	sim.readback_updated.connect(_on_readback)
	sim.stats_updated.connect(hud.on_stats)
	sim.saved.connect(func(p: String) -> void: hud.flash("World saved: " + p.get_file()))
	if not sim.heights.is_empty():
		_on_heightmap.call_deferred(sim.heights) # the world already exists
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Debug: --hide=creatures,grass,shadows,terrain,sim to measure what costs what.
	var hide: String = Launch.args.get("hide", "")
	_agents.visible = not hide.contains("creatures")
	_grass_hidden = hide.contains("grass")
	_terrain_hidden = hide.contains("terrain")
	_trees_hidden = hide.contains("trees")
	if hide.contains("shadows"):
		_sun.shadow_enabled = false
	if hide.contains("sim"):
		sim.paused = true
	if Launch.args.has("overview"): # debug: high third-person camera
		player.set("_orbit", float(Launch.args.overview))
		player.pitch = -0.45
	if _bench_seconds > 0.0:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


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
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 70.0
	add_child(_sun)


func _setup_world_meshes() -> void:
	for n in ["terrain", "water", "plant", "creature"]:
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

	# Every plant near the player: the GPU simulation fills one MultiMesh per form.
	for f in 4:
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = sim.plant_multimeshes[f]
		mmi.material_override = _mats.plant
		if f < 2: # grass and flowers are too small to be worth shadows
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visible = false
		add_child(mmi)
		_plants.append(mmi)

	# The creatures: the GPU simulation fills this (persistent) MultiMesh directly.
	_agents = MultiMeshInstance3D.new()
	_agents.multimesh = sim.agent_multimesh
	_agents.material_override = _mats.creature
	add_child(_agents)


func _on_heightmap(heights: PackedFloat32Array) -> void:
	var first := _heights.is_empty()
	_heights = heights
	var img := Image.create_from_data(_world, _world, false, Image.FORMAT_RF, heights.to_byte_array())
	img.convert(Image.FORMAT_RH) # half floats filter linearly everywhere
	_height_tex = ImageTexture.create_from_image(img)
	for m in _mats.values():
		m.set_shader_parameter("height_tex", _height_tex)
		# Bound only now: before build, Texture2DRD hands out a placeholder that
		# materials keep using.
		m.set_shader_parameter("field_tex", sim.texture)
	_terrain.visible = not _terrain_hidden
	_water.visible = true
	for f in 4:
		_plants[f].visible = not (_grass_hidden if f < 2 else _trees_hidden)
	player.height_at = height_at
	if first:
		if Launch.focus_m.x >= 0.0:
			player.spawn(_land_near(Launch.focus_m)) # coming from the 2D map
			Launch.focus_m = Vector2(-1, -1)
		else:
			player.spawn(_find_spawn())
	hud.set_loading(false)


## Bilinear terrain height (m) at world x, z (metres); cell centres at +0.5 like the GPU.
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


func _find_spawn() -> Vector3:
	var rng := RandomNumberGenerator.new()
	rng.seed = sim.seed_value
	var best := Vector3(_world_m * 0.5, 0, _world_m * 0.5)
	for i in 400:
		var x := rng.randf() * _world_m
		var z := rng.randf() * _world_m
		var h := height_at(x, z)
		if h > 1.0 and h < 25.0:
			return Vector3(x, h, z)
		if h > best.y:
			best = Vector3(x, h, z)
	return best


## The closest dry ground to a point (m), searching outward in rings.
func _land_near(p: Vector2) -> Vector3:
	for r in range(0, 3000, 20):
		for k in maxi(1, r / 10):
			var a := TAU * k / maxi(1, r / 10)
			var x := fposmod(p.x + cos(a) * r, _world_m)
			var z := fposmod(p.y + sin(a) * r, _world_m)
			var h := height_at(x, z)
			if h > 0.5:
				return Vector3(x, h, z)
	return _find_spawn()


func switch_to_2d() -> void:
	if _tracking:
		sim.send_command(Simulation.Cmd.UNTRACK)
	Launch.switch_view(Launch.VIEW_2D, Vector2(player.position.x, player.position.z))


func reset_world() -> void:
	_tracking = false
	player.spectating = false
	sim.reset()
	hud.flash("New world")
	resume()


func resume() -> void:
	hud.open_menu(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).physical_keycode
		if k == KEY_ESCAPE:
			if hud.is_menu_open():
				resume()
			else:
				hud.open_menu(true)
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			return
		if hud.is_menu_open():
			return
		match k:
			KEY_TAB: switch_to_2d()
			KEY_V: player.first_person = not player.first_person
			KEY_H: hud.toggle_help()
			KEY_P:
				sim.paused = not sim.paused
				hud.flash("Simulation paused" if sim.paused else "Simulation running")
			KEY_BRACKETLEFT: _set_tps(ticks_per_second / 1.5)
			KEY_BRACKETRIGHT: _set_tps(ticks_per_second * 1.5)
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5: sim.color_mode = k - KEY_1
			KEY_G: _cycle_presence()
			KEY_E:
				sim.send_command(Simulation.Cmd.SOW)
				hud.flash("Sowed grass and flowers")
			KEY_C: _breed()
			KEY_T: _toggle_follow()
	elif event is InputEventMouseButton and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if not hud.is_menu_open():
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		var b := (event as InputEventMouseButton).button_index
		if b == MOUSE_BUTTON_LEFT:
			_act_on_aimed(Simulation.Cmd.KILL, REACH, "Struck!")
		elif b == MOUSE_BUTTON_RIGHT:
			_act_on_aimed(Simulation.Cmd.FEED, REACH, "Fed it (+4 energy)")


func _set_tps(v: float) -> void:
	ticks_per_second = clampf(v, 1.0, 40.0)
	hud.flash("Simulation speed: %.0f ticks/s" % ticks_per_second)


func _act_on_aimed(cmd: int, reach: float, text: String) -> bool:
	if _aimed.is_empty():
		return false
	if _aimed.dist > reach:
		hud.flash("Too far (%.0f m), get within %.0f m" % [_aimed.dist, reach])
		return false
	sim.send_command(cmd, 8)
	hud.flash(text)
	return true


func _breed() -> void:
	_act_on_aimed(Simulation.Cmd.SPAWN, BREED_REACH, "Bred 8 mutated clones")


func _toggle_follow() -> void:
	if _tracking:
		_stop_follow("Stopped following")
		return
	if _aimed.is_empty():
		hud.flash("Aim at an agent to follow it")
		return
	sim.player.target = _aimed.index
	sim.player.target_pos = _to_cells(_aimed.pos)
	sim.send_command(Simulation.Cmd.TRACK)
	_tracking = true
	_track_confirmed = false
	sim.player.inspect_tracked = true
	player.spectating = true
	player.spectate_target = player.position
	hud.flash("Following (T to stop, mouse to orbit)")


func _stop_follow(text: String) -> void:
	_tracking = false
	sim.player.inspect_tracked = false
	player.spectating = false
	sim.send_command(Simulation.Cmd.UNTRACK)
	hud.flash(text)


func _cycle_presence() -> void:
	presence = ((presence + 1) % 4) as Presence
	if presence == Presence.LURE:
		if not _inspected.is_empty():
			_lure_pheno = _inspected.pheno
		elif _lure_pheno == 0:
			presence = Presence.PREY
	if presence == Presence.PREY:
		_health = 100.0
	hud.flash("Presence: " + PRESENCE_NAMES[presence])


func _process(delta: float) -> void:
	if _heights.is_empty():
		return
	# Pace the simulation: THINK phases per second = ticks/s x chunks.
	if not sim.paused:
		_phase_acc += delta * ticks_per_second * sim.think_chunks
	var n := int(_phase_acc)
	_phase_acc -= n
	sim.phase_budget = mini(sim.phase_budget + n, sim.think_chunks * 3)
	sim.phase_fraction = _phase_acc

	var p: Vector3 = player.position
	sim.player.pos = Vector2(p.x, p.z) / _cell
	sim.player.speed = player.horizontal_speed / ticks_per_second / _cell
	sim.player.presence = 0 if presence == Presence.INVISIBLE else 1
	sim.player.presence_pheno = _presence_pheno()

	_pick()
	# Terrain and water follow the player (snapped to the grid spacing).
	var snap := Vector3(snappedf(p.x, TERRAIN_SPACING * 2.0), 0, snappedf(p.z, TERRAIN_SPACING * 2.0))
	_terrain.position = snap
	_water.position = snap
	_update_hud()
	if _bench_seconds > 0.0:
		_bench(delta)


func _presence_pheno() -> int:
	match presence:
		Presence.PREDATOR: return Simulation.pack_pheno(2.5, 1.0, 0.0, 0, 2.0)
		Presence.LURE: return _lure_pheno
		Presence.PREY: return Simulation.pack_pheno(1.0, 0.0, 0.5, 0, 1.0)
	return 0


## World position (m) -> simulation position (cells, wrapped).
func _to_cells(p: Vector3) -> Vector2:
	return Vector2(fposmod(p.x, _world_m), fposmod(p.z, _world_m)) / _cell


## Ray from the camera against the nearby agents reported by the GPU.
func _pick() -> void:
	var cam: Camera3D = player.cam
	var origin := cam.global_position
	var dir := -cam.global_basis.z
	var best_t := PICK_RANGE
	_aimed = {}
	for a in _near:
		var r: float = a.size * 0.6
		var c: Vector3 = a.pos + Vector3(0, a.size * 0.45, 0)
		var oc := origin - c
		var bq := oc.dot(dir)
		var disc := bq * bq - (oc.length_squared() - r * r)
		if disc < 0.0:
			continue
		var t := -bq - sqrt(disc)
		if t > 0.0 and t < best_t:
			best_t = t
			_aimed = a
	if not _aimed.is_empty():
		_aimed.dist = (player.position - _aimed.pos).length()
		sim.player.target = _aimed.index
		sim.player.target_pos = _to_cells(_aimed.pos)
	elif not _tracking:
		sim.player.target = -1
	hud.set_aiming(not _aimed.is_empty())


func _on_readback(data: PackedByteArray) -> void:
	var u := func(k: int) -> int: return data.decode_u32(k * 4)
	var f := func(k: int) -> float: return data.decode_float(k * 4)
	# Nearby agents (world positions around the player at the time of the read).
	_near.clear()
	for i in mini(u.call(0), Simulation.MAX_NEAR):
		var o := 64 + i * 8
		_near.append({
			"index": u.call(o),
			"pos": Vector3(f.call(o + 1), f.call(o + 2), f.call(o + 3)),
			"size": f.call(o + 4),
			"pheno": u.call(o + 5),
			"action": u.call(o + 7),
		})
	# Only draw as many creature instances as the GPU wrote (plus room to grow).
	var written: int = u.call(62)
	_agents.multimesh.visible_instance_count = mini(Simulation.MAX_VIS, written + written / 8 + 256)
	for form in 4:
		var pw: int = u.call(56 + form)
		_plants[form].multimesh.visible_instance_count = mini(Simulation.MAX_PVIS, pw + pw / 8 + 256)
	# Damage predators dealt to the player.
	var dmg: int = u.call(1)
	if _last_damage >= 0 and dmg > _last_damage and presence == Presence.PREY:
		_health -= (dmg - _last_damage) / 1000.0 * 10.0
		hud.flash("You are being eaten!")
		if _health <= 0.0:
			_health = 100.0
			player.spawn(_find_spawn())
			hud.flash("You were eaten. Respawned.")
	_last_damage = dmg
	# The inspected (aimed or followed) agent.
	var idx: int = u.call(2)
	if _tracking and u.call(3) != 0xffffffff:
		_track_confirmed = true
	if idx == 0xffffffff:
		_inspected = {}
		if _tracking and _track_confirmed and u.call(3) == 0xffffffff:
			_stop_follow("The agent you followed died")
		return
	var genes := []
	for q in Simulation.GENES:
		genes.append(f.call(16 + q))
	var pheno: int = u.call(10)
	var ap_cells := Vector2(f.call(4), f.call(5))
	var ap := ap_cells * _cell
	_inspected = {
		"index": idx,
		"pos": ap,
		"heading": f.call(6),
		"energy": f.call(7),
		"age": int(f.call(8)),
		"neural": (u.call(9) & 2) != 0,
		"pheno": pheno,
		"hue": Simulation.unpack_pheno(pheno).hue,
		"generation": u.call(12),
		"action": u.call(13),
		"speed": f.call(14),
		"height": f.call(15),
		"genes": genes,
		"tracked": _tracking,
	}
	if _tracking:
		# Unwrap the agent's position next to the player and move the camera there.
		var p: Vector3 = player.position
		var d := Vector2(wrapf(ap.x - p.x, -_world_m * 0.5, _world_m * 0.5), wrapf(ap.y - p.z, -_world_m * 0.5, _world_m * 0.5))
		player.spectate_target = Vector3(p.x + d.x, f.call(15), p.z + d.y)
		player.spectate_size = 0.35 + Simulation.unpack_pheno(pheno).size * 0.45
		sim.player.target = idx
		sim.player.target_pos = ap_cells


func _update_hud() -> void:
	var lines := PackedStringArray()
	lines.append("Presence: %s   (G)" % PRESENCE_NAMES[presence])
	lines.append("Sim: %.0f ticks/s%s   (P, [ ])" % [ticks_per_second, "  PAUSED" if sim.paused else ""])
	if player.swimming:
		lines.append("Swimming")
	hud.set_status(lines)
	if presence == Presence.PREY:
		_health = minf(_health + get_process_delta_time() * 2.0, 100.0)
	hud.set_health(_health, presence == Presence.PREY)
	var shown := _inspected.duplicate()
	if not shown.is_empty():
		var p: Vector3 = player.position
		shown.distance = Vector2(wrapf(shown.pos.x - p.x, -_world_m * 0.5, _world_m * 0.5),
				wrapf(shown.pos.y - p.z, -_world_m * 0.5, _world_m * 0.5)).length()
	hud.show_agent(shown)


func _bench(delta: float) -> void:
	_bench_time += delta
	if Launch.args.has("autotest"):
		_autotest()
	if Launch.args.has("motiontest"):
		_motion_test()
	if int(_bench_time) != int(_bench_time - delta):
		print("3D t=%ds fps=%d tick=%d near=%d aimed=%s plants drawn=%s" % [int(_bench_time), Engine.get_frames_per_second(),
				sim.tick, _near.size(), "yes" if not _aimed.is_empty() else "no",
				_plants.map(func(m: MultiMeshInstance3D) -> int: return m.multimesh.visible_instance_count)])
	if Launch.args.has("seektree") and _bench_time > 3.0 and not has_meta("sought"): # debug: go to an inland tree
		set_meta("sought", true)
		var buf := RenderingServer.multimesh_get_buffer(sim.plant_multimeshes[3].get_rid())
		var best := Vector3.INF
		for k in _plants[3].multimesh.visible_instance_count:
			var o := Vector3(buf[k * 20 + 3], buf[k * 20 + 7], buf[k * 20 + 11])
			if buf[k * 20 + 5] != 0.0 and o.y > 3.0 and o.distance_to(player.position) < best.distance_to(player.position):
				best = o
		if best != Vector3.INF:
			var at := best + Vector3(14, 0, 14)
			player.spawn(Vector3(at.x, height_at(at.x, at.z), at.z))
	if _bench_time >= _bench_seconds:
		_bench_seconds = 0.0
		var img := get_viewport().get_texture().get_image()
		var path := OS.get_user_data_dir().path_join("bench3d.png")
		img.save_png(path)
		print("screenshot: ", path)
		get_tree().quit()


## --autotest=1 (with --bench): follow the nearest agent, then feed it, breed it
## and strike it, printing what the GPU reports after each step.
var _auto_step := 0
var _auto_t0 := -1.0


func _autotest() -> void:
	if _auto_t0 < 0.0:
		if _bench_time < 3.0 or _near.is_empty():
			return
		var best := {}
		for a in _near:
			var d: float = (a.pos - player.position).length()
			if best.is_empty() or d < best.d:
				best = a
				best.d = d
		best.dist = 2.0
		_aimed = best
		_toggle_follow()
		_auto_t0 = _bench_time
	var t := _bench_time - _auto_t0
	var steps := [1.0, 1.6, 2.4, 3.2, 3.4, 5.0]
	if _auto_step >= steps.size() or t < steps[_auto_step]:
		return
	var around := 0
	for a in _near:
		if (a.pos - player.position).length() < 8.0:
			around += 1
	print("autotest t=%.1f following=%s subject=%s agents within 8 m=%d" % [
			t, _tracking, _describe(_inspected), around])
	if not _inspected.is_empty():
		_aimed = {"index": _inspected.index, "dist": 2.0, "pos": player.position}
	match _auto_step:
		0: _act_on_aimed(Simulation.Cmd.FEED, REACH, "feed")
		1: _breed()
		2: _act_on_aimed(Simulation.Cmd.KILL, REACH, "kill")
		3: print("  fleeing within 12 m before: %d" % _count_fleeing())
		4: presence = Presence.PREDATOR
		5: print("  fleeing within 12 m as a predator: %d" % _count_fleeing())
	_auto_step += 1


## --motiontest=1 (with --bench): follow the nearest agent and measure how evenly
## its displayed position advances from frame to frame.
var _motion := {"steps": [], "back": 0, "last": Vector2.INF, "dir": Vector2.ZERO}


func _motion_test() -> void:
	if not _tracking:
		if _bench_time > 2.0 and not _near.is_empty():
			_aimed = _near[0]
			_aimed.dist = 1.0
			_toggle_follow()
		return
	if _inspected.is_empty() or not _track_confirmed:
		return
	var p: Vector2 = _inspected.pos
	if _motion.last != Vector2.INF:
		var step: Vector2 = p - _motion.last
		_motion.steps.append(step.length())
		if _motion.dir != Vector2.ZERO and step.length() > 0.01 and step.normalized().dot(_motion.dir) < -0.5:
			_motion.back += 1 # jumped backwards
			print("  backward: frame %d tick %d step %s prev dir %s action %s speed %.2f" % [_motion.steps.size(), sim.tick, step, _motion.dir, _inspected.action, _inspected.speed])
		if step.length() > 0.4:
			print("  big step: frame %d tick %d len %.2f" % [_motion.steps.size(), sim.tick, step.length()])
		if step.length() > 0.01:
			_motion.dir = step.normalized()
	_motion.last = p
	if _motion.steps.size() == 900:
		var steps: Array = _motion.steps.duplicate()
		steps.sort()
		var moving := steps.filter(func(x: float) -> bool: return x > 0.001)
		var med: float = moving[moving.size() / 2] if not moving.is_empty() else 0.0
		print("motiontest: frames=%d moving=%d median step=%.3f m  95th=%.3f  max=%.3f  backward jumps=%d" % [
				steps.size(), moving.size(), med, moving[int(moving.size() * 0.95)] if not moving.is_empty() else 0.0,
				steps[-1], _motion.back])


func _count_fleeing() -> int:
	var n := 0
	for a in _near:
		if a.action == 2 and (a.pos - player.position).length() < 12.0:
			n += 1
	return n


func _describe(a: Dictionary) -> String:
	if a.is_empty():
		return "none"
	return "#%d energy=%.2f/%.2f age=%d gen=%d action=%s neural=%s" % [a.index, a.energy, a.genes[3], a.age,
			a.generation, Simulation.ACTIONS[mini(a.action, Simulation.ACTIONS.size() - 1)], a.neural]
