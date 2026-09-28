extends Node
## Autoload "Launch": owns the one Simulation (so it keeps running across scene
## changes), the settings shared by the menu and both views, command-line options
## and switching between scenes.
##
## Command-line options (after "--"):
##   --view=2d|3d   skip the menu      --capacity=N  --plants=N  --world=N  --cell=M  --pop=N  --seed=N
##   --mode=utility|neural|mixed       --<param>=X  any Simulation.params entry
##   --steps=N  --bench=SECONDS  --profile=1   (benchmarking, see main.gd / explorer.gd)

const MENU := "res://menu.tscn"
const VIEW_2D := "res://main.tscn"
const VIEW_3D := "res://explorer.tscn"
const VIEW_LIFE := "res://life_main.tscn" ## unified-life simulation (experimental)
const VIEW_LIFE_3D := "res://life_explorer.tscn"
const LifeSim := preload("res://scripts/life/life_sim.gd")
const MODES := {"utility": 0, "neural": 1, "mixed": 2}
const Simulation := preload("res://scripts/simulation.gd")

var brain_mode := 2
var initial_pop := 60_000
var capacity := 300_000
var plant_capacity := 6_000_000 ## individual plants (half of it is sown at the start)
var world_size := 1024 ## cells per side
var cell_size := 8.0 ## metres per cell
var seed_value := 1
var param_overrides := {}
var args := {} ## raw command-line options
var auto_started := false ## the menu only honours --view once
var sim: Node ## the running simulation (null until a view first needs it)
var life: Node ## the unified-life simulation (null until its view first opens)
## World position (m) the next view should open at (from the view you left);
## negative when there is none.
var focus_m := Vector2(-1, -1)
var pre_evolve := 0 ## ticks a new world is fast-forwarded before a view opens
var _built_with := {} ## settings the running world was started with


func _init() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	capacity = int(args.get("capacity", capacity))
	world_size = int(args.get("world", world_size))
	cell_size = float(args.get("cell", cell_size))
	plant_capacity = int(args.get("plants", plant_capacity))
	initial_pop = int(args.get("pop", initial_pop))
	seed_value = int(args.get("seed", seed_value))
	brain_mode = MODES.get(args.get("mode", ""), brain_mode)


## Copy the shared settings (and any --param overrides) into a Simulation.
func configure(sim: Node) -> void:
	sim.capacity = start_capacity()
	sim.world_size = world_size
	sim.cell_size = cell_size
	sim.plant_capacity = plant_capacity
	sim.initial_plants = plant_capacity / 2
	sim.initial_pop = mini(initial_pop, Simulation.MAX_CAPACITY)
	sim.seed_value = seed_value
	sim.brain_mode = brain_mode
	for k in args:
		if sim.params.has(k):
			sim.params[k] = float(args[k])
	for k in param_overrides:
		sim.params[k] = param_overrides[k]


## Starting agent storage. It is not a population limit: the storage grows with
## the populations (see Simulation.grow); energy limits them.
func start_capacity() -> int:
	return maxi(capacity, ceili(initial_pop * 1.5 / 50_000.0) * 50_000)


func go(scene: String) -> void:
	get_tree().change_scene_to_file.call_deferred(scene)


## The running simulation, created and built on first use.
func get_sim() -> Node:
	if sim == null:
		sim = Simulation.new()
		sim.name = "Simulation"
		add_child(sim)
		sim.restarted.connect(func() -> void: _built_with = settings())
		sim.stats_updated.connect(func(st: Dictionary) -> void: sim.set_meta("alive", st.alive))
		configure(sim)
		sim.build()
	return sim


## The unified-life simulation, created and built on first use (--life=seeded
## starts it seeded instead of primordial).
func get_life() -> Node:
	if life == null:
		life = LifeSim.new()
		life.name = "LifeSim"
		add_child(life)
		life.world_size = world_size
		life.cell_size = cell_size
		life.seed_value = seed_value
		if args.get("life", "") == "seeded":
			life.start_mode = LifeSim.Start.SEEDED
		for k in args:
			if life.params.has(k):
				life.params[k] = float(args[k])
		life.build()
	return life


func settings() -> Dictionary:
	return {"brain": brain_mode, "pop": initial_pop, "capacity": capacity, "world": world_size,
			"cell": cell_size, "seed": seed_value, "plants": plant_capacity}


## True when the menu settings differ from the running world's.
func settings_changed() -> bool:
	return sim != null and settings() != _built_with


## Start a new world with the current settings (rebuilds GPU buffers only if the
## world's size changed).
func restart() -> void:
	var s := get_sim()
	var structural: bool = (s.capacity != start_capacity() or s.world_size != world_size or s.cell_size != cell_size
			or s.plant_capacity != plant_capacity)
	configure(s)
	if structural:
		s.build()
	else:
		s.reset()


func _ready() -> void:
	if args.has("switchtest"):
		_switch_test()
	if args.has("savetest"):
		_save_test()
	if args.has("evolvetest"):
		_evolve_test()
	if args.has("growtest"):
		_grow_test()


## --view=menu --evolvetest=N (dev): pre-evolve a new world from the menu, open 2D.
func _evolve_test() -> void:
	var tree := get_tree()
	await tree.create_timer(1.0).timeout
	pre_evolve = int(args.evolvetest)
	var t0 := Time.get_ticks_msec()
	get_sim()
	tree.current_scene._start_evolving(VIEW_2D)
	while tree.current_scene == null or tree.current_scene.name != "Main":
		await tree.process_frame
	print("evolvetest: reached the 2D view at tick %d after %.1f s" % [sim.tick, (Time.get_ticks_msec() - t0) / 1000.0])
	var st: Dictionary = await sim.stats_updated
	print("evolvetest: tick=%d alive=%d generation=%d plants=%s" % [st.tick, st.alive, st.max_generation, st.plant_forms])
	tree.quit()


## --savetest=1 (dev): run, save, keep running, load the save, check it resumes.
func _save_test() -> void:
	var tree := get_tree()
	await tree.create_timer(6.0).timeout
	print("savetest: saving at tick %d, last alive %s" % [sim.tick, sim.get_meta("alive", "?")])
	var t0 := Time.get_ticks_msec()
	var path := save_world()
	var saved_path: String = await sim.saved
	var h := Simulation.read_header(saved_path)
	print("savetest: saved %s in %d ms, %.1f MB, header tick=%d alive=%d" % [saved_path.get_file(),
			Time.get_ticks_msec() - t0, FileAccess.get_file_as_bytes(saved_path).size() / 1e6, h.tick, h.alive])
	await tree.create_timer(3.0).timeout
	print("savetest: world went on to tick %d" % sim.tick)
	t0 = Time.get_ticks_msec()
	load_world(path)
	print("savetest: loaded in %d ms, tick now %d" % [Time.get_ticks_msec() - t0, sim.tick])
	var st: Dictionary = await sim.stats_updated
	print("savetest: after load tick=%d alive=%d plants~%d forms=%s (saved %d plants)" % [st.tick, st.alive, st.plants, st.plant_forms, h.plants])
	st = await sim.stats_updated
	print("savetest: still running tick=%d alive=%d births/t=%.0f" % [st.tick, st.alive, st.births_per_tick])
	tree.quit()


## --switchtest=1 (dev): 2D -> 3D -> 2D while the world keeps running, then quit.
func _switch_test() -> void:
	var tree := get_tree()
	for step in ["2d", "3d", "2d"]:
		await tree.create_timer(4.0).timeout
		var scene := tree.current_scene
		var p: Variant = scene.get("player")
		print("switchtest: in %s tick=%d alive_last=%s %s" % [scene.name, sim.tick if sim else -1,
				sim.get_meta("alive", "?") if sim else "?",
				("player at (%.0f, %.0f)" % [p.position.x, p.position.z]) if p != null else ""])
		scene.get_viewport().get_texture().get_image().save_png(OS.get_user_data_dir().path_join("switch_%s.png" % scene.name))
		if step == "2d" and scene.has_method("switch_to_3d"):
			scene.switch_to_3d()
		elif scene.has_method("switch_to_2d"):
			scene.switch_to_2d()
	await tree.create_timer(3.0).timeout
	print("switchtest: back in %s tick=%d" % [tree.current_scene.name, sim.tick])
	tree.quit()


## Save the running world under user://worlds; returns the file path.
func save_world() -> String:
	var name := "world_%s_tick%d.abmworld" % [Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_"), sim.tick]
	var path := Simulation.SAVE_DIR.path_join(name)
	sim.save_world(path)
	return path


## Saved worlds, newest first: [{path, header}].
func saved_worlds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var dir := DirAccess.open(Simulation.SAVE_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".abmworld"):
			var path := Simulation.SAVE_DIR.path_join(f)
			var h := Simulation.read_header(path)
			if not h.is_empty():
				out.append({"path": path, "header": h})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.header.time > b.header.time)
	return out


## Replace the running world with a saved one (menu settings follow it).
func load_world(path: String) -> bool:
	var s := sim
	if s == null:
		s = Simulation.new()
		s.name = "Simulation"
		add_child(s)
		s.restarted.connect(func() -> void: _built_with = settings())
		s.stats_updated.connect(func(st: Dictionary) -> void: s.set_meta("alive", st.alive))
		sim = s
	var h := Simulation.read_header(path)
	if h.is_empty():
		return false
	capacity = h.capacity
	plant_capacity = h.get("plant_capacity", plant_capacity)
	world_size = h.world
	cell_size = h.cell
	seed_value = h.seed
	brain_mode = h.brain
	return s.load_world(path)


## Switch view without touching the simulation, opening at `focus` (metres).
func switch_view(scene: String, focus: Vector2) -> void:
	focus_m = focus
	go(scene)


## --growtest=1 (dev): enlarge the storage mid-run and check nothing is lost.
func _grow_test() -> void:
	var tree := get_tree()
	await tree.create_timer(5.0).timeout
	var st: Dictionary = await sim.stats_updated
	print("growtest: before tick=%d alive=%d plants~%d" % [st.tick, st.alive, st.plants])
	sim.grow(sim.capacity + 100_000, sim.plant_capacity + 1_000_000)
	await sim.grown
	for i in 3:
		st = await sim.stats_updated
		print("growtest: after tick=%d alive=%d plants~%d room=%d/%d" % [st.tick, st.alive, st.plants, st.capacity, st.plant_capacity])
	tree.quit()
