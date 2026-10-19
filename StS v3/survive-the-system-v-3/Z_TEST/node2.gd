extends Node
## Benchmark: agent-side scatter stamp vs grid-side difference array + 3D prefix sum.
## Attach to a Node in an empty scene and run. Results print to the Output panel.
##
## Both methods produce the SAME result: each agent adds w to every cell of a
## (2r+1) x (2ry+1) x (2r+1) box around itself, clipped at the grid edges.
##
##  A) scatter : agent loops over its box             cost ~ N * box_volume
##  B) grid    : agent writes 8 corners into a diff   cost ~ 8 * N + ~5 * cells
##               grid, then 3 prefix-sum passes rebuild the boxes

const R_MAX := 4      # horizontal radius (x and z)
const RY_MAX := 3     # vertical radius (y)
const RUNS := 5       # timed runs per config (after 1 warm-up)

# [W, H, D, agent_count]
var configs := [
	[32, 16, 32, 100],
	[32, 16, 32, 1000],
	[32, 16, 32, 10000],
	[64, 32, 64, 100],
	[64, 32, 64, 1000],
	[64, 32, 64, 10000],
	[128, 32, 128, 100],
	[128, 32, 128, 1000],
	[128, 32, 128, 10000],
]

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 12345
	print("grid            cells     agents   density   scatter_ms   grid_ms    speedup   max_diff")
	for cfg in configs:
		_run_config(cfg[0], cfg[1], cfg[2], cfg[3])


func _run_config(W: int, H: int, D: int, n: int) -> void:
	var cells := W * H * D

	# random agents: flattened cell index, radii, weight
	var cs := PackedInt32Array(); cs.resize(n)
	var rs := PackedInt32Array(); rs.resize(n)
	var rys := PackedInt32Array(); rys.resize(n)
	var ws := PackedFloat32Array(); ws.resize(n)
	for a in n:
		cs[a] = rng.randi_range(0, cells - 1)
		rs[a] = rng.randi_range(0, R_MAX)
		rys[a] = rng.randi_range(0, RY_MAX)
		ws[a] = rng.randf_range(0.1, 1.0)

	var rate_a := PackedFloat32Array(); rate_a.resize(cells)
	var rate_b := PackedFloat32Array(); rate_b.resize(cells)
	var diff := PackedFloat32Array(); diff.resize((W + 1) * (H + 1) * (D + 1))

	# warm-up
	stamp_scatter(rate_a, W, H, D, cs, rs, rys, ws)
	stamp_grid(rate_b, diff, W, H, D, cs, rs, rys, ws)

	var t_a := 0
	var t_b := 0
	for i in RUNS:
		var t0 := Time.get_ticks_usec()
		stamp_scatter(rate_a, W, H, D, cs, rs, rys, ws)
		var t1 := Time.get_ticks_usec()
		stamp_grid(rate_b, diff, W, H, D, cs, rs, rys, ws)
		var t2 := Time.get_ticks_usec()
		t_a += t1 - t0
		t_b += t2 - t1

	var max_diff := 0.0
	for i in cells:
		max_diff = maxf(max_diff, absf(rate_a[i] - rate_b[i]))

	var ms_a := t_a / 1000.0 / RUNS
	var ms_b := t_b / 1000.0 / RUNS
	print("%-14s %9d %9d %9.4f %12.2f %9.2f %9.2fx %10.6f" % [
		"%dx%dx%d" % [W, H, D], cells, n, float(n) / cells,
		ms_a, ms_b, ms_a / maxf(ms_b, 0.001), max_diff])


# ---------------------------------------------------------------------------
# A) Agent-side scatter: every agent writes its whole (clipped) box.
# ---------------------------------------------------------------------------
func stamp_scatter(rate: PackedFloat32Array, W: int, H: int, D: int,
		cs: PackedInt32Array, rs: PackedInt32Array, rys: PackedInt32Array,
		ws: PackedFloat32Array) -> void:
	rate.fill(0.0)
	var PLANE := W * H
	for a in cs.size():
		var c := cs[a]
		var r := rs[a]
		var ry := rys[a]
		var w := ws[a]
		var cx := c % W
		var cy := (c / W) % H
		var cz := c / PLANE

		var x0 := maxi(cx - r, 0);  var x1 := mini(cx + r, W - 1)
		var y0 := maxi(cy - ry, 0); var y1 := mini(cy + ry, H - 1)
		var z0 := maxi(cz - r, 0);  var z1 := mini(cz + r, D - 1)

		for z in range(z0, z1 + 1):
			var zo := z * PLANE
			for y in range(y0, y1 + 1):
				var base := zo + y * W
				for x in range(x0, x1 + 1):
					rate[base + x] += w


# ---------------------------------------------------------------------------
# B) Grid-side: 3D difference array + prefix sums.
#    Each agent marks only the 8 corners of its box (+w / -w by
#    inclusion-exclusion). Summing along x, then y, then z turns those
#    corners back into filled boxes. Handles per-agent radii.
#    diff is padded to (W+1)(H+1)(D+1) so the "end" corners never go out
#    of bounds.
# ---------------------------------------------------------------------------
func stamp_grid(rate: PackedFloat32Array, diff: PackedFloat32Array,
		W: int, H: int, D: int,
		cs: PackedInt32Array, rs: PackedInt32Array, rys: PackedInt32Array,
		ws: PackedFloat32Array) -> void:
	var PLANE := W * H
	var W1 := W + 1
	var P1 := W1 * (H + 1)
	diff.fill(0.0)

	# 1) corners
	for a in cs.size():
		var c := cs[a]
		var r := rs[a]
		var ry := rys[a]
		var w := ws[a]
		var cx := c % W
		var cy := (c / W) % H
		var cz := c / PLANE

		var x0 := maxi(cx - r, 0);  var x1 := mini(cx + r, W - 1) + 1
		var y0 := maxi(cy - ry, 0); var y1 := mini(cy + ry, H - 1) + 1
		var z0 := maxi(cz - r, 0);  var z1 := mini(cz + r, D - 1) + 1

		var i := x0 + y0 * W1 + z0 * P1
		var dx := x1 - x0
		var dy := (y1 - y0) * W1
		var dz := (z1 - z0) * P1

		diff[i] += w
		diff[i + dx] -= w
		diff[i + dy] -= w
		diff[i + dz] -= w
		diff[i + dx + dy] += w
		diff[i + dx + dz] += w
		diff[i + dy + dz] += w
		diff[i + dx + dy + dz] -= w

	# 2) prefix sum along x
	for z in D:
		for y in H:
			var base := y * W1 + z * P1
			for x in range(1, W):
				diff[base + x] += diff[base + x - 1]

	# 3) prefix sum along y
	for z in D:
		for y in range(1, H):
			var base := y * W1 + z * P1
			for x in W:
				diff[base + x] += diff[base + x - W1]

	# 4) prefix sum along z
	for z in range(1, D):
		for y in H:
			var base := y * W1 + z * P1
			for x in W:
				diff[base + x] += diff[base + x - P1]

	# 5) copy padded grid -> rate
	for z in D:
		for y in H:
			var src := y * W1 + z * P1
			var dst := y * W + z * PLANE
			for x in W:
				rate[dst + x] = diff[src + x]
