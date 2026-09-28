extends RefCounted
## The universal body rig of Unified Life: every possible part of a body, in
## part-local coordinates. shaders/organism.gdshader places, bends, scales or
## hides each part per instance from the organism's developed body, so a tree,
## a creeping vine, an anemone and a six-legged grazer are the same mesh.
##
## Vertex attributes: UV2 = (part, index), UV.x = side (0 / 1), VERTEX = local
## coordinates, NORMAL = local normal. Vertex colour is white (the instance
## colour comes through unchanged).
##   0 segment (index 0-5): unit sphere
##   1 appendage (index 0-3, side): tapered tube along +Y from 0 to 1
##   2 surface (index 0-3, side, UV.y = 0-2 position along the appendage): leaf / sail,
##     x along 0..1, z across -0.5..0.5
##   3 jaw (index 0 upper, 1 lower): plate along +Y, x across
##   4 eye (side): unit sphere
##   5 root (index 0-3): tube along +Y
##   6 thorn (index 0-5 segment, side): cone along +Y

enum Part { SEGMENT, APPENDAGE, SURFACE, JAW, EYE, ROOT, THORN }


static func build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		_sphere(st, Part.SEGMENT, i, 0, 7, 5)
	for k in 4:
		for side in 2:
			_tube(st, Part.APPENDAGE, k, side, 5, 3, 0.35)
			for leaf in 3: # along the appendage: tip, 70 %, 45 %
				_leaf(st, k, side, leaf)
	for j in 2:
		_plate(st, j)
	for side in 2:
		_sphere(st, Part.EYE, 0, side, 5, 3)
	for k in 4:
		_tube(st, Part.ROOT, k, 0, 4, 2, 0.2)
	for i in 6:
		for side in 2:
			_tube(st, Part.THORN, i, side, 3, 1, 0.0)
	st.index()
	return st.commit()


static func _vert(st: SurfaceTool, part: int, index: int, side: int, v: Vector3, n: Vector3, sub := 0) -> void:
	st.set_color(Color.WHITE)
	st.set_uv(Vector2(side, sub))
	st.set_uv2(Vector2(part, index))
	st.set_normal(n)
	st.add_vertex(v)


static func _sphere(st: SurfaceTool, part: int, index: int, side: int, seg: int, rings: int) -> void:
	for r in rings:
		var t0 := PI * r / rings
		var t1 := PI * (r + 1) / rings
		for s in seg:
			var p0 := TAU * s / seg
			var p1 := TAU * (s + 1) / seg
			var a := _dir(t0, p0)
			var b := _dir(t0, p1)
			var d := _dir(t1, p0)
			var e := _dir(t1, p1)
			for v in [a, d, b, b, d, e]:
				_vert(st, part, index, side, v, v)


## Tube along +Y from 0 to 1, radius 1 at the base tapering to `tip`.
static func _tube(st: SurfaceTool, part: int, index: int, side: int, sides: int, rings: int, tip: float) -> void:
	for r in rings:
		var y0 := float(r) / rings
		var y1 := float(r + 1) / rings
		var r0 := lerpf(1.0, tip, y0)
		var r1 := lerpf(1.0, tip, y1)
		for s in sides:
			var a0 := TAU * s / sides
			var a1 := TAU * (s + 1) / sides
			var n0 := Vector3(cos(a0), 0, sin(a0))
			var n1 := Vector3(cos(a1), 0, sin(a1))
			var q := [n0 * r0 + Vector3(0, y0, 0), n1 * r0 + Vector3(0, y0, 0), n0 * r1 + Vector3(0, y1, 0), n1 * r1 + Vector3(0, y1, 0)]
			var nn := [n0, n1, n0, n1]
			for k in [0, 2, 1, 1, 2, 3]:
				_vert(st, part, index, side, q[k], nn[k])


## Leaf / sail: a pointed blade in the local XZ plane, x from 0 to 1.
static func _leaf(st: SurfaceTool, index: int, side: int, sub: int) -> void:
	var pts := [Vector3(0, 0, 0), Vector3(0.35, 0, -0.5), Vector3(0.75, 0, -0.35), Vector3(1, 0, 0),
			Vector3(0.75, 0, 0.35), Vector3(0.35, 0, 0.5)]
	# A fan from the stem covers the whole blade exactly once (overlapping
	# coplanar triangles would z-fight and flicker).
	for k in range(1, pts.size() - 1):
		for v in [pts[0], pts[k], pts[k + 1]]:
			_vert(st, Part.SURFACE, index, side, v, Vector3.UP, sub)


## Jaw plate: a wedge along +Y, x across.
static func _plate(st: SurfaceTool, index: int) -> void:
	var pts := [Vector3(-0.5, 0, 0), Vector3(0.5, 0, 0), Vector3(0.3, 1, 0), Vector3(-0.3, 1, 0), Vector3(0, 0.6, 0.25)]
	var tris := [[0, 1, 2], [0, 2, 3], [0, 4, 1], [1, 4, 2], [2, 4, 3], [3, 4, 0]]
	for tri in tris:
		for k in tri:
			_vert(st, Part.JAW, index, 0, pts[k], Vector3(0, 0, 1))


static func _dir(theta: float, phi: float) -> Vector3:
	return Vector3(sin(theta) * cos(phi), cos(theta), sin(theta) * sin(phi))
