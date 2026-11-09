extends Node
## Photosynthesis stamp benchmark - results shown as a table on screen.
##
## Compares 4 ways to produce the same field (each agent adds w to a clipped
## (2r+1) x (2ry+1) x (2r+1) box around its cell):
##
##   scatter     : each agent writes its whole box                 (1 thread)
##   scatter_mt  : grid split into z-slabs, each thread owns a slab
##                 and stamps only the part of every box inside it  (no races)
##   grid        : 8 corners per agent into a difference array,
##                 then prefix sums along x, y, z                    (1 thread)
##   grid_mt     : same, corners serial, prefix/copy passes threaded
##
## Usage:
##   - Attach to any Node and run / export.
##   - Optional: set `target` to a RichTextLabel or Label in your scene and the
##     table is written there. If empty, the script creates its own full-screen
##     RichTextLabel with a "Run again" button.

@export var target: Node      ## RichTextLabel (table) or Label (plain text). Optional.
@export var auto_run := true

const R_MAX := 4      # horizontal radius (x, z)
const RY_MAX := 3     # vertical radius (y)
const RUNS := 3       # timed runs per method (after 1 warm-up)

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

const METHODS := ["scatter", "scatter_mt", "grid", "grid_mt"]

# --- current config (members so worker tasks can reach them) ---------------
var W := 0
var H := 0
var D := 0
var PLANE := 0     # W * H
var W1 := 0        # padded width  (W + 1)
var P1 := 0        # padded plane  ((W + 1) * (H + 1))
var agent_count := 0
var slab_count := 1

var ax := PackedInt32Array()
var ay := PackedInt32Array()
var az := PackedInt32Array()
var rs := PackedInt32Array()
var rys := PackedInt32Array()
var ws := PackedFloat64Array()

var rate := PackedFloat64Array()   # output field, W*H*D
var diff := PackedFloat64Array()   # padded difference grid, (W+1)(H+1)(D+1)

# --- display ------------------------------------------------------------------
var rich: RichTextLabel
var label: Label
var run_button: Button
var results: Array[Dictionary] = []
var status := ""
var running := false
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	return
	if target is RichTextLabel:
		rich = target
	elif target is Label:
		label = target
	else:
		_build_ui()
	if rich:
		rich.bbcode_enabled = true
	if auto_run:
		run_all()


# =============================================================================
# Display
# =============================================================================
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	root.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)

	run_button = Button.new()
	run_button.text = "Run again"
	run_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	run_button.pressed.connect(run_all)
	vb.add_child(run_button)

	rich = RichTextLabel.new()
	rich.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rich.selection_enabled = true
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
	rich.add_theme_font_override("normal_font", mono)
	rich.add_theme_font_override("bold_font", mono)
	rich.add_theme_font_size_override("normal_font_size", 15)
	rich.add_theme_font_size_override("bold_font_size", 15)
	vb.add_child(rich)


func _info_lines() -> PackedStringArray:
	return PackedStringArray([
		"CPU: %s  |  logical cores: %d  |  worker_pool max_threads: %s" % [
			OS.get_processor_name(), OS.get_processor_count(),
			str(ProjectSettings.get_setting("threading/worker_pool/max_threads", -1))],
		"Godot %s  |  %s build  |  R_MAX=%d  RY_MAX=%d  |  %d runs + 1 warm-up  |  ms per tick" % [
			Engine.get_version_info().string,
			"debug" if OS.is_debug_build() else "release", R_MAX, RY_MAX, RUNS],
	])


func _render() -> void:
	if rich:
		rich.text = _render_bbcode()
	elif label:
		label.text = _render_plain()


func _render_bbcode() -> String:
	var s := "[b]Photo stamp benchmark[/b]\n"
	for line in _info_lines():
		s += "[color=#9aa4b2]%s[/color]\n" % line
	s += "[color=#e6c35c]%s[/color]\n\n" % status

	var heads := ["grid", "cells", "agents", "density",
			"scatter", "scatter_mt", "grid", "grid_mt", "best", "max_err"]
	s += "[table=%d]" % heads.size()
	for h in heads:
		s += "[cell bg=#1c2230 padding=10,4,10,4][b]%s[/b][/cell]" % h

	for r in results:
		var cells := [
			"%dx%dx%d" % [r.W, r.H, r.D],
			str(r.cells),
			str(r.agents),
			"%.4f" % r.density,
		]
		for m in METHODS:
			var t := "%.2f" % r[m]
			if m == r.best:
				t = "[color=#6fdc8c][b]%s[/b][/color]" % t
			cells.append(t)
		cells.append("[color=#6fdc8c]%s[/color]" % r.best)
		var err_col := "#9aa4b2" if r.err < 1e-6 else "#ff6b6b"
		cells.append("[color=%s]%.1e[/color]" % [err_col, r.err])
		for c in cells:
			s += "[cell padding=10,2,10,2]%s[/cell]" % c
	s += "[/table]"
	return s


func _render_plain() -> String:
	var lines := PackedStringArray(["Photo stamp benchmark"])
	lines.append_array(_info_lines())
	lines.append(status)
	lines.append("")
	lines.append("%-12s %8s %7s %8s | %9s %10s %9s %9s | %-10s %8s" % [
		"grid", "cells", "agents", "density",
		"scatter", "scatter_mt", "grid", "grid_mt", "best", "max_err"])
	lines.append("-".repeat(110))
	for r in results:
		lines.append("%-12s %8d %7d %8.4f | %9.2f %10.2f %9.2f %9.2f | %-10s %8.1e" % [
			"%dx%dx%d" % [r.W, r.H, r.D], r.cells, r.agents, r.density,
			r.scatter, r.scatter_mt, r.grid, r.grid_mt, r.best, r.err])
	return "\n".join(lines)


# =============================================================================
# Benchmark driver
# =============================================================================
func run_all() -> void:
	if running:
		return
	running = true
	if run_button:
		run_button.disabled = true
	results.clear()
	rng.seed = 12345

	for i in configs.size():
		var cfg: Array = configs[i]
		status = "Running %d / %d  (%dx%dx%d, %d agents)..." % [
			i + 1, configs.size(), cfg[0], cfg[1], cfg[2], cfg[3]]
		_render()
		# let the screen redraw before the next blocking config
		await get_tree().process_frame
		await get_tree().process_frame
		results.append(_run_config(cfg[0], cfg[1], cfg[2], cfg[3]))

	status = "Done."
	_render()
	running = false
	if run_button:
		run_button.disabled = false


func _run_config(w: int, h: int, d: int, n: int) -> Dictionary:
	W = w; H = h; D = d
	PLANE = W * H
	W1 = W + 1
	P1 = W1 * (H + 1)
	agent_count = n
	var cells := W * H * D

	# random agents (positions decomposed once, outside timing, for all methods)
	ax.resize(n); ay.resize(n); az.resize(n)
	rs.resize(n); rys.resize(n); ws.resize(n)
	for a in n:
		ax[a] = rng.randi_range(0, W - 1)
		ay[a] = rng.randi_range(0, H - 1)
		az[a] = rng.randi_range(0, D - 1)
		rs[a] = rng.randi_range(0, R_MAX)
		rys[a] = rng.randi_range(0, RY_MAX)
		ws[a] = rng.randf_range(0.1, 1.0)

	rate.resize(cells)
	diff.resize(P1 * (D + 1))

	var r := {"W": W, "H": H, "D": D, "cells": cells, "agents": n,
			"density": float(n) / cells}

	r.scatter = _time(scatter_serial)
	var ref := rate.duplicate()      # reference result

	r.scatter_mt = _time(scatter_mt)
	var err := _max_err(ref)
	r.grid = _time(grid_serial)
	err = maxf(err, _max_err(ref))
	r.grid_mt = _time(grid_mt)
	err = maxf(err, _max_err(ref))
	r.err = err

	var best: String = METHODS[0]
	for m in METHODS:
		if r[m] < r[best]:
			best = m
	r.best = best
	return r


func _time(method: Callable) -> float:
	method.call()   # warm-up
	var t0 := Time.get_ticks_usec()
	for i in RUNS:
		method.call()
	return (Time.get_ticks_usec() - t0) / 1000.0 / RUNS


func _max_err(ref: PackedFloat64Array) -> float:
	var m := 0.0
	for i in rate.size():
		m = maxf(m, absf(rate[i] - ref[i]))
	return m


func _group(fn: Callable, count: int) -> void:
	var id := WorkerThreadPool.add_group_task(fn, count)
	WorkerThreadPool.wait_for_group_task_completion(id)


# =============================================================================
# A) Scatter
# =============================================================================
func scatter_serial() -> void:
	rate.fill(0.0)
	slab_count = 1
	_scatter_slab(0)


func scatter_mt() -> void:
	rate.fill(0.0)
	slab_count = mini(D, maxi(OS.get_processor_count(), 1))
	_group(_scatter_slab, slab_count)


## Stamps every agent, but only the z-range of slab i. Slabs never overlap,
## so threads never write the same cell.
func _scatter_slab(i: int) -> void:
	var w := W
	var h := H
	var plane := PLANE
	var zs := i * D / slab_count
	var ze := (i + 1) * D / slab_count - 1
	for a in agent_count:
		var r := rs[a]
		var cz := az[a]
		var z0 := maxi(cz - r, zs)
		var z1 := mini(cz + r, ze)
		if z0 > z1:
			continue
		var cx := ax[a]
		var cy := ay[a]
		var ry := rys[a]
		var wt := ws[a]
		var x0 := maxi(cx - r, 0)
		var x1 := mini(cx + r, w - 1)
		var y0 := maxi(cy - ry, 0)
		var y1 := mini(cy + ry, h - 1)
		for z in range(z0, z1 + 1):
			var zo := z * plane
			for y in range(y0, y1 + 1):
				var base := zo + y * w
				for x in range(x0, x1 + 1):
					rate[base + x] += wt


# =============================================================================
# B) Grid: difference array + prefix sums
# =============================================================================
func grid_serial() -> void:
	diff.fill(0.0)
	_deposit()
	for z in D: _prefix_x(z)
	for z in D: _prefix_y(z)
	for y in H: _prefix_z(y)
	for z in D: _copy_out(z)


func grid_mt() -> void:
	diff.fill(0.0)
	_deposit()                 # serial: corners of different agents can collide
	_group(_prefix_x, D)       # every row independent
	_group(_prefix_y, D)       # every z-plane independent
	_group(_prefix_z, H)       # every y-row (across depth) independent
	_group(_copy_out, D)


func _deposit() -> void:
	var w := W
	var h := H
	var d := D
	var w1 := W1
	var p1 := P1
	for a in agent_count:
		var r := rs[a]
		var ry := rys[a]
		var wt := ws[a]
		var x0 := maxi(ax[a] - r, 0);  var x1 := mini(ax[a] + r, w - 1) + 1
		var y0 := maxi(ay[a] - ry, 0); var y1 := mini(ay[a] + ry, h - 1) + 1
		var z0 := maxi(az[a] - r, 0);  var z1 := mini(az[a] + r, d - 1) + 1

		var i := x0 + y0 * w1 + z0 * p1
		var dx := x1 - x0
		var dy := (y1 - y0) * w1
		var dz := (z1 - z0) * p1

		diff[i] += wt
		diff[i + dx] -= wt
		diff[i + dy] -= wt
		diff[i + dz] -= wt
		diff[i + dx + dy] += wt
		diff[i + dx + dz] += wt
		diff[i + dy + dz] += wt
		diff[i + dx + dy + dz] -= wt


func _prefix_x(z: int) -> void:
	var w := W
	var w1 := W1
	var zo := z * P1
	for y in H:
		var base := zo + y * w1
		for x in range(1, w):
			diff[base + x] += diff[base + x - 1]


func _prefix_y(z: int) -> void:
	var w := W
	var w1 := W1
	var zo := z * P1
	for y in range(1, H):
		var base := zo + y * w1
		for x in w:
			diff[base + x] += diff[base + x - w1]


func _prefix_z(y: int) -> void:
	var w := W
	var p1 := P1
	var yo := y * W1
	for z in range(1, D):
		var base := yo + z * p1
		for x in w:
			diff[base + x] += diff[base + x - p1]


func _copy_out(z: int) -> void:
	var w := W
	for y in H:
		var src := y * W1 + z * P1
		var dst := y * w + z * PLANE
		for x in w:
			rate[dst + x] = diff[src + x]
