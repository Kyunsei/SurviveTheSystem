extends RefCounted
## Procedural low-poly meshes for the 3D explorer.


## A creature facing -Z, about 1 unit long. Parts are tagged in vertex colour
## alpha for creature.gdshader: 1.0 body, 0.75 horns, 0.5 eyes, 0.25 feet.
static func creature() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := Color(1, 1, 1, 1.0)
	_ellipsoid(st, Vector3(0, 0.42, 0.05), Vector3(0.34, 0.3, 0.46), body, 10, 6)
	_ellipsoid(st, Vector3(0, 0.62, -0.42), Vector3(0.22, 0.2, 0.22), body, 8, 5)
	_ellipsoid(st, Vector3(0, 0.46, 0.5), Vector3(0.06, 0.06, 0.12), body, 4, 3) # tail
	for x in [-1.0, 1.0]:
		_ellipsoid(st, Vector3(0.1 * x, 0.68, -0.6), Vector3(0.055, 0.055, 0.04), Color(0, 0, 0, 0.5), 5, 3)
		_ellipsoid(st, Vector3(0.12 * x, 0.86, -0.36), Vector3(0.04, 0.15, 0.04), Color(1, 1, 1, 0.75), 4, 3)
		for z in [-1.0, 1.0]:
			_ellipsoid(st, Vector3(0.2 * x, 0.09, 0.24 * z), Vector3(0.08, 0.09, 0.1), Color(1, 1, 1, 0.25), 4, 3)
	st.index()
	return st.commit()


## Plant models. Parts are tagged in vertex colour alpha for plant.gdshader:
## 1.0 leaves / broadleaf crown, 0.75 conifer crown, 0.5 petals, 0.4 fruit,
## 0.25 trunk and stems. Each model sits on y = 0.


## A grass patch (one clonal individual): tussocks spread over a disc of radius
## 1, about 0.5 m tall. The simulation scales it to the plant's crown and height.
static func grass_tussock() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in 11:
		var centre := _disc_point(c, 11, 0.85)
		for i in 7:
			var a := i * TAU / 7.0 + c * 0.9 + (i % 3) * 0.4
			var r := 0.04 + 0.06 * float(i % 3) / 2.0
			var base := centre + Vector3(cos(a), 0, sin(a)) * 0.015
			var side := Vector3(-sin(a), 0, cos(a)) * 0.012
			var tip := centre + Vector3(cos(a), 0, sin(a)) * r + Vector3(0, 0.3 + 0.2 * float((i + c) % 3) / 2.0, 0)
			_blade(st, base, side, tip, Color(1, 1, 1, 1.0))
	st.index()
	return st.commit()


## A flower patch (one clonal individual): leafy clumps and blossoms spread over
## a disc of radius 1, about 0.6 m tall.
static func flower_plant() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for c in 6:
		var centre := _disc_point(c, 6, 0.8)
		for i in 4: # leaves
			var a := i * TAU / 4.0 + c
			var out := Vector3(cos(a), 0, sin(a))
			_blade(st, centre + out * 0.01, Vector3(-sin(a), 0, cos(a)) * 0.025, centre + out * 0.09 + Vector3(0, 0.22, 0), Color(1, 1, 1, 1.0))
		for f in 2:
			var a := f * PI + c * 1.3
			var top := centre + Vector3(cos(a) * 0.05, 0.5 + 0.08 * f, sin(a) * 0.05)
			_blade(st, centre, Vector3(0.006, 0, 0.006), top, Color(1, 1, 1, 0.25)) # stem
			for k in 5: # petals
				var pa := k * TAU / 5.0
				var p1 := top + Vector3(cos(pa), 0.01, sin(pa)) * 0.05
				var p2 := top + Vector3(cos(pa + 0.9), 0.01, sin(pa + 0.9)) * 0.05
				for v in [top + Vector3(0, 0.015, 0), p2, p1]:
					st.set_color(Color(1, 1, 1, 0.5))
					st.set_normal(Vector3.UP)
					st.set_uv(Vector2(0.5, 1.0))
					st.add_vertex(v)
	st.index()
	return st.commit()


## Evenly spread point k of n in a disc (sunflower pattern).
static func _disc_point(k: int, n: int, radius: float) -> Vector3:
	var r := radius * sqrt((k + 0.5) / n)
	var a := k * 2.39996
	return Vector3(cos(a) * r, 0, sin(a) * r)


## A shrub about 1.2 m tall made of leafy lumps, with berries.
static func bush() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf := Color(1, 1, 1, 1.0)
	_ellipsoid(st, Vector3(0, 0.55, 0), Vector3(0.9, 0.6, 0.9), leaf, 8, 5)
	_ellipsoid(st, Vector3(0.6, 0.5, 0.3), Vector3(0.6, 0.5, 0.6), leaf, 6, 4)
	_ellipsoid(st, Vector3(-0.5, 0.45, -0.4), Vector3(0.7, 0.45, 0.6), leaf, 6, 4)
	_ellipsoid(st, Vector3(0.1, 0.95, -0.3), Vector3(0.5, 0.4, 0.5), leaf, 6, 4)
	for i in 7:
		var a := i * 2.3
		_ellipsoid(st, Vector3(cos(a) * 0.8, 0.5 + 0.08 * (i % 3), sin(a) * 0.8), Vector3.ONE * 0.08, Color(1, 1, 1, 0.4), 4, 3)
	st.index()
	return st.commit()


## A tree about 7.5 m tall with both a broadleaf crown (alpha 1.0) and a conifer
## crown (alpha 0.75); the shader keeps one depending on the lineage. Fruit hangs
## in the broadleaf crown.
static func tree() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_ellipsoid(st, Vector3(0, 1.6, 0), Vector3(0.25, 1.8, 0.25), Color(1, 1, 1, 0.25), 6, 4)
	var broad := Color(1, 1, 1, 1.0)
	_ellipsoid(st, Vector3(0, 4.3, 0), Vector3(1.9, 1.7, 1.9), broad, 8, 5)
	_ellipsoid(st, Vector3(0.7, 5.3, 0.3), Vector3(1.2, 1.1, 1.2), broad, 6, 4)
	_ellipsoid(st, Vector3(-0.6, 4.9, -0.5), Vector3(1.3, 1.2, 1.3), broad, 6, 4)
	for i in 8:
		var a := i * 2.4
		_ellipsoid(st, Vector3(cos(a) * 1.8, 3.6 + 0.3 * (i % 3), sin(a) * 1.8), Vector3.ONE * 0.16, Color(1, 1, 1, 0.4), 4, 3)
	var cone := Color(1, 1, 1, 0.75)
	_ellipsoid(st, Vector3(0, 3.0, 0), Vector3(1.7, 0.9, 1.7), cone, 8, 4)
	_ellipsoid(st, Vector3(0, 4.4, 0), Vector3(1.3, 0.9, 1.3), cone, 8, 4)
	_ellipsoid(st, Vector3(0, 5.7, 0), Vector3(0.85, 0.9, 0.85), cone, 6, 4)
	_ellipsoid(st, Vector3(0, 6.8, 0), Vector3(0.4, 0.8, 0.4), cone, 5, 3)
	st.index()
	return st.commit()


static func _blade(st: SurfaceTool, base: Vector3, side: Vector3, tip: Vector3, col: Color) -> void:
	for v in [[base - side, 0.0], [base + side, 0.0], [tip, 1.0]]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.set_uv(Vector2(0.5, v[1]))
		st.add_vertex(v[0])


## The player avatar (third person), facing -Z.
static func player_body() -> Node3D:
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.85, 0.55, 0.25)
	var capsule := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.7
	capsule.mesh = cm
	capsule.position.y = 0.85
	capsule.material_override = mat
	root.add_child(capsule)
	var visor := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.4, 0.14, 0.2)
	visor.mesh = bm
	visor.position = Vector3(0, 1.45, -0.22)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.1, 0.12, 0.15)
	vmat.metallic = 0.6
	vmat.roughness = 0.2
	visor.material_override = vmat
	root.add_child(visor)
	return root


static func _ellipsoid(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, seg: int, rings: int) -> void:
	for i in rings:
		var t0 := PI * i / rings
		var t1 := PI * (i + 1) / rings
		for j in seg:
			var p0 := TAU * j / seg
			var p1 := TAU * (j + 1) / seg
			var a := _dir(t0, p0)
			var b := _dir(t0, p1)
			var d := _dir(t1, p0)
			var e := _dir(t1, p1)
			# Clockwise seen from outside (Godot's front face).
			for v in [a, d, b, b, d, e]:
				st.set_color(col)
				st.set_normal((v / r).normalized())
				st.add_vertex(c + v * r)


static func _dir(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
