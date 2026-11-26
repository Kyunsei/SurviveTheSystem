class_name DamageEffects
extends Node
## Visual feedback when an agent gets hurt:
##   - in the sprite shader: white flash turning red, squash, sideways shake (fades out)
##   - a floating damage number above the agent (optional)
##
## Call from anywhere (species scripts, PlayerController...):
##     DamageEffects.hit(species, index, amount)
## If there's no DamageEffects node in the scene, one is created automatically on the
## first hit. Add one yourself to change its settings in the inspector.
## amount = biomass (or energy) lost. 0 = flash only, at full strength, no number.
##
## Works with test3d.gdshader (hit_* uniforms). Nothing is packed in the agent texture:
## each species keeps a small ring of its HIT_SLOTS most recent hits as shader uniforms,
## so it costs nothing when nobody is hurt.

const SLOTS := 16                            # must match HIT_SLOTS in the shader

static var _inst: DamageEffects

@export var camera: FlyCamera                # for the wrap / planet position (auto if empty)
@export var debug := true                    # print each hit + warn about setup problems

@export_group("Flash")
@export var flash_time := 0.35               # seconds
@export var full_flash_damage := 20.0        # damage giving the strongest flash
@export var min_strength := 0.35             # even a tiny hit is visible

@export_group("Numbers")
@export var show_numbers := true
@export var number_time := 0.8               # seconds on screen
@export var number_rise := 40.0              # pixels it floats up
@export var number_font_size := 14
@export var number_color := Color(1.0, 0.35, 0.3)
@export var max_numbers := 40                # oldest removed beyond this


class Fx:
	var mat: ShaderMaterial
	var ids := PackedInt32Array()
	var start := PackedFloat32Array()
	var strength := PackedFloat32Array()
	var next := 0
	var last := -1000.0
	var active := false


var _now := 0.0                              # own clock (TIME in shaders rolls over)
var _fx := {}                                # species -> Fx
var _numbers: Array[Dictionary] = []         # {label, pos, t}
var _layer := CanvasLayer.new()


func _enter_tree() -> void:
	_inst = self


func _exit_tree() -> void:
	if _inst == self:
		_inst = null


func _ready() -> void:
	_layer.layer = 80
	add_child(_layer)
	if camera == null:
		camera = get_viewport().get_camera_3d() as FlyCamera


# --- Public ----------------------------------------------------------------------

## Agent `i` of species `sp` lost `amount`. Safe to call when no DamageEffects exists.
static func hit(sp, i: int, amount := 0.0) -> void:
	if _inst == null:
		# No node in the scene: make one (added at the end of the frame, usable now)
		_inst = DamageEffects.new()
		_inst.name = "DamageEffects"
		var root := (Engine.get_main_loop() as SceneTree).root
		root.add_child.call_deferred(_inst)
		print("DamageEffects: no node in the scene, created one")
	_inst._hit(sp, i, amount)


# --- Internals -------------------------------------------------------------------

func _hit(sp, i: int, amount: float) -> void:
	if sp == null or i < 0:
		return
	var fx := _get_fx(sp)
	if debug:
		print("DamageEffects: %s #%d  -%.2f  %s" % [sp.species_name, i, amount,
				"ok" if fx != null else "NO EFFECT (see warning)"])
	if fx == null:
		return

	var strength := 1.0
	if amount > 0.0:
		strength = clampf(amount / maxf(full_flash_damage, 0.001), min_strength, 1.0)

	# Already flashing: restart its slot, else take the oldest one
	var k := fx.ids.find(i)
	if k < 0:
		k = fx.next
		fx.next = (k + 1) % SLOTS
	fx.ids[k] = i
	fx.start[k] = _now
	fx.strength[k] = strength
	fx.last = _now
	fx.active = true

	fx.mat.set_shader_parameter("hit_ids", fx.ids)
	fx.mat.set_shader_parameter("hit_start", fx.start)
	fx.mat.set_shader_parameter("hit_strength", fx.strength)
	fx.mat.set_shader_parameter("hit_now", _now)
	fx.mat.set_shader_parameter("hit_active", true)

	if show_numbers and amount > 0.0:
		_add_number(sp, i, amount)


func _get_fx(sp) -> Fx:
	var fx: Fx = _fx.get(sp)
	if fx != null and is_instance_valid(fx.mat):
		return fx
	var mat := sp.renderer3D.material_override as ShaderMaterial
	if mat == null:
		push_warning("DamageEffects: %s has no ShaderMaterial in renderer3D.material_override" % sp.species_name)
		return null
	# The shader must have the hit_* uniforms (new test3d.gdshader)
	var has_hit := false
	for u in mat.shader.get_shader_uniform_list():
		if u["name"] == "hit_ids":
			has_hit = true
			break
	if not has_hit:
		push_warning("DamageEffects: the shader of %s (%s) has no hit_* uniforms: use the new test3d.gdshader" \
				% [sp.species_name, mat.shader.resource_path])
	fx = Fx.new()
	fx.mat = mat
	fx.ids.resize(SLOTS)
	fx.ids.fill(-1)
	fx.start.resize(SLOTS)
	fx.strength.resize(SLOTS)
	mat.set_shader_parameter("hit_time", flash_time)
	_fx[sp] = fx
	return fx


func _process(delta: float) -> void:
	_now += delta

	# Keep the shader clock running only while something flashes
	for fx: Fx in _fx.values():
		if not fx.active or not is_instance_valid(fx.mat):
			continue
		if _now - fx.last <= flash_time:
			fx.mat.set_shader_parameter("hit_now", _now)
		else:
			fx.active = false
			fx.mat.set_shader_parameter("hit_active", false)

	_update_numbers(delta)


# --- Floating numbers --------------------------------------------------------------

func _add_number(sp, i: int, amount: float) -> void:
	var label := Label.new()
	label.text = ("-%d" % roundi(amount)) if amount >= 1.0 else ("-%.1f" % amount)
	label.add_theme_font_size_override("font_size", number_font_size)
	label.add_theme_color_override("font_color", number_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	_layer.add_child(label)

	# Above the head, at the moment of the hit (the number doesn't follow the agent)
	var q: Vector2 = (sp.renderer3D.multimesh.mesh as QuadMesh).size
	var pos: Vector3 = sp.position_array[i] + Vector3(0.0, q.y * sp.current_size[i], 0.0)
	_numbers.append({"label": label, "pos": pos, "t": 0.0,
			"jitter": randf_range(-10.0, 10.0)})   # several hits don't stack exactly

	while _numbers.size() > max_numbers:
		_numbers.pop_front()["label"].queue_free()


func _update_numbers(delta: float) -> void:
	if _numbers.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var center := camera.get_wrap_center() if camera != null else Vector3.ZERO

	for n in _numbers.duplicate():
		n["t"] += delta
		var t: float = n["t"] / maxf(number_time, 0.01)
		var label: Label = n["label"]
		if t >= 1.0:
			_numbers.erase(n)
			label.queue_free()
			continue

		var p := WorldWrap.curve(WorldWrap.nearest_image(n["pos"], center), center)
		if cam == null or cam.is_position_behind(p):
			label.visible = false
			continue
		var screen := cam.unproject_position(p)
		var sz := label.get_combined_minimum_size()
		label.position = screen + Vector2(n["jitter"] - sz.x * 0.5, -sz.y - number_rise * t)
		label.modulate.a = 1.0 - t * t                # stays readable, then fades fast
		label.scale = Vector2.ONE * (1.0 + 0.4 * maxf(0.0, 1.0 - t * 6.0))   # small pop
		label.visible = true
