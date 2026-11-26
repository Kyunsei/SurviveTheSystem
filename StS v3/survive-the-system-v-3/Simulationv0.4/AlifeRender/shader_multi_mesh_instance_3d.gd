class_name AlifeRenderer3D
extends MultiMeshInstance3D

var sprite: Texture2D
var hframes := 1
var vframes := 1
var pixel_size := 0.01  # world units per pixel, same idea as Sprite3D
var billboard := true
var billboard_y_only := false
var selected_id := -1

const SHADOW_SHADER :=preload("uid://cm0rwd0o8onrb")
const GROUND_SHADER := preload("res://Simulationv0.4/AlifeRender/Alife3d_ground.gdshader")
const CASTER_SHADER := preload("res://Simulationv0.4/AlifeRender/Alife3d_caster.gdshader")
var _shadow: MultiMeshInstance3D
var _ground: MultiMeshInstance3D               # flat sprite on the ground (species with ground_sprite)
var _caster: MultiMeshInstance3D               # invisible sphere casting the sun's shadow (native_shadow)
var _copies := 1                               # billboard sprites per agent (species' render_copies)
var is_plant = true

func setup(agent_data: AlifeRenderingData, alife:ALIFE, world_size: Vector3, color: Color) -> void:
	assert(agent_data.tex != null, "AgentData.resize() must be called before renderer setup")

	sprite =  alife.sprite
	is_plant = alife.photosynthesis_on
	_copies = clampi(alife.render_copies, 1, 3)
	hframes= alife.hframes
	vframes = alife.vframes

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D     # 12 floats per instance
	mm.use_colors = false

	#sprite = preload("res://Alife/Plant/Grass/grass.png") #TODO
	var frame_px := sprite.get_size() / Vector2(hframes, vframes)
	var quad := QuadMesh.new()
	quad.size = frame_px * pixel_size
	# Put the pivot at the sprite's feet instead of its centre
	quad.center_offset = Vector3(0, quad.size.y * 0.5, 0)


	mm.mesh = quad #mesh
	mm.custom_aabb = AABB(-world_size, world_size * 2.0) #STILL NEED TO CHECK THIS
	multimesh = mm

	var mat := ShaderMaterial.new()
	mat.shader = preload("uid://w65faynydapu")
	mat.set_shader_parameter("agent_data", agent_data.tex)
	mat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
	mat.set_shader_parameter("alive_color", color)
	mat.set_shader_parameter("sprite_texture", sprite)
	mat.set_shader_parameter("billboard", billboard)
	mat.set_shader_parameter("billboard_y_only", billboard_y_only)
	mat.set_shader_parameter("selected_id", selected_id)
	mat.set_shader_parameter("wind_strength", 0.3 if is_plant else 0.0)
	mat.set_shader_parameter("hframes", hframes)
	mat.set_shader_parameter("vframes", vframes)
	mat.set_shader_parameter("world_height", world_size.y)
	mat.set_shader_parameter("world_size", world_size)
	# Several sprites per agent (e.g. moss): 1, then 2 from a third of the life cycle,
	# 3 from two thirds; copy_params can override any of the shader's copy_* / stage_* settings
	mat.set_shader_parameter("sprite_scale", alife.sprite_scale)   # every species: base sprite size
	mat.set_shader_parameter("copies", _copies)
	if _copies > 1:
		var max_life: int = maxi(alife.max_life_cycle, 1)
		mat.set_shader_parameter("stage_for_2", ceili(max_life / 3.0))
		mat.set_shader_parameter("stage_for_3", ceili(max_life * 2.0 / 3.0))
	for key in alife.copy_params:
		mat.set_shader_parameter(key, alife.copy_params[key])
	material_override = mat
	ensure_instances3D(agent_data.capacity())

	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Real shadow from the sun (DirectionalLight3D): invisible flattened spheres, SHADOWS_ONLY
	if alife.native_shadow:
		var sphere := SphereMesh.new()             # radius 0.5: the shader scales it
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.radial_segments = 12
		sphere.rings = 6
		var cmm := MultiMesh.new()
		cmm.transform_format = MultiMesh.TRANSFORM_3D
		cmm.mesh = sphere
		cmm.custom_aabb = mm.custom_aabb

		var cmat := ShaderMaterial.new()
		cmat.shader = CASTER_SHADER
		cmat.set_shader_parameter("agent_data", agent_data.tex)
		cmat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
		cmat.set_shader_parameter("world_height", world_size.y)
		cmat.set_shader_parameter("world_size", world_size)
		cmat.set_shader_parameter("sprite_height", quad.size.y * alife.sprite_scale)
		if alife.shadow_from_photo_range:
			var sc: Vector3 = alife.world.SUN_cell_size
			cmat.set_shader_parameter("use_photo_range", true)
			cmat.set_shader_parameter("sun_cell_size", maxf(sc.x, sc.z))
		for k in alife.caster_params:              # per-species: light_gaps, canopy_at, flatten...
			cmat.set_shader_parameter(k, alife.caster_params[k])

		_caster = MultiMeshInstance3D.new()
		_caster.multimesh = cmm
		_caster.material_override = cmat
		_caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(_caster)

	# Round shadow on the ground, only for species without a ground sprite or a real shadow
	# (the ground sprite takes its place)
	if alife.ground_sprite == null and not alife.native_shadow:
		var smm := MultiMesh.new()
		smm.transform_format = MultiMesh.TRANSFORM_3D
		smm.mesh = QuadMesh.new()                  # 1 x 1, centered
		smm.custom_aabb = mm.custom_aabb

		var smat := ShaderMaterial.new()
		smat.shader = SHADOW_SHADER
		if alife.shadow_from_photo_range:
			# As wide as the area it shades: photo range (sent in the action bits) x sun cell
			var sc: Vector3 = alife.world.SUN_cell_size
			smat.set_shader_parameter("use_photo_range", true)
			smat.set_shader_parameter("sun_cell_size", maxf(sc.x, sc.z))
		smat.set_shader_parameter("agent_data", agent_data.tex)
		smat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
		smat.set_shader_parameter("world_height", world_size.y)
		smat.set_shader_parameter("world_size", world_size)

		# Drawn after the ground sprites (moss patches...), so shadows show on top of them
		smat.render_priority = 1
		for k in alife.shadow_params:              # per-species: strength, softness, lift...
			smat.set_shader_parameter(k, alife.shadow_params[k])

		_shadow = MultiMeshInstance3D.new()
		_shadow.multimesh = smm
		_shadow.material_override = smat
		_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_shadow)

	# Ground sprite: a flat textured quad under each agent (only species that have one)
	if alife.ground_sprite != null:
		var gmm := MultiMesh.new()
		gmm.transform_format = MultiMesh.TRANSFORM_3D
		gmm.mesh = QuadMesh.new()                  # 1 x 1, centered; the shader lays it flat
		gmm.custom_aabb = mm.custom_aabb

		var gmat := ShaderMaterial.new()
		gmat.shader = GROUND_SHADER
		gmat.set_shader_parameter("agent_data", agent_data.tex)
		gmat.set_shader_parameter("tex_width", AlifeRenderingData.TEX_W)
		gmat.set_shader_parameter("world_height", world_size.y)
		gmat.set_shader_parameter("world_size", world_size)
		gmat.set_shader_parameter("ground_texture", alife.ground_sprite)
		gmat.set_shader_parameter("ground_scale", alife.ground_sprite_scale)
		gmat.set_shader_parameter("ground_scales_with_size", alife.ground_sprite_follows_size)
		for key in alife.ground_params:            # per-species shader settings (stages, offsets...)
			gmat.set_shader_parameter(key, alife.ground_params[key])

		gmat.render_priority = -1                  # under the other species' shadows

		_ground = MultiMeshInstance3D.new()
		_ground.multimesh = gmm
		_ground.material_override = gmat
		_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_ground)

	ensure_instances3D(agent_data.capacity())

func set_frame(index: int, frame: int) -> void:
	multimesh.set_instance_custom_data(index, Color(frame, 0, 0, 0))


func _ensure(mm : MultiMesh, n: int) -> void:
	if n <= mm.instance_count:
		return
	mm.instance_count = n
	var b := PackedFloat32Array([1, 0, 0, 0,  0, 1, 0, 0,  0, 0, 1, 0])   # 3D identity
	while b.size() < n * 12:
		b.append_array(b)
	b.resize(n * 12)
	mm.buffer = b

func set_count(n: int) -> void:
	multimesh.visible_instance_count = n * _copies
	if _shadow:
		_shadow.multimesh.visible_instance_count = n
	if _ground:
		_ground.multimesh.visible_instance_count = n
	if _caster:
		_caster.multimesh.visible_instance_count = n

func ensure_instances3D(n: int) -> void:
	_ensure(multimesh, n * _copies)
	if _shadow:
		_ensure(_shadow.multimesh, n)
	if _ground:
		_ensure(_ground.multimesh, n)
	if _caster:
		_ensure(_caster.multimesh, n)


func set_wrap_view(on: bool) -> void:
	var m := WorldWrap.mask if on else Vector3.ZERO
	material_override.set_shader_parameter("wrap_axes", m)
	if _shadow:
		_shadow.material_override.set_shader_parameter("wrap_axes", m)
	if _ground:
		_ground.material_override.set_shader_parameter("wrap_axes", m)
	if _caster:
		_caster.material_override.set_shader_parameter("wrap_axes", m)
