class_name SeriesGraph
extends VBoxContainer
## One series plotted against time, with a dropdown to choose which series it shows.
## Created and managed by GraphStack: you normally don't add it by hand.

signal key_changed(graph: SeriesGraph, old_key: String, new_key: String)

var stack: GraphStack
var data: GraphData
var key := ""
var x_key := "Time"

var y_from_zero := true
var max_points := 800
var font_size := 11
var line_width := 1.5
var left_margin := 52.0      # fixed so all graphs in the stack line up vertically
var right_margin := 64.0     # room for the last value
var background := Color(0, 0, 0, 0.35)
var grid_color := Color(1, 1, 1, 0.08)
var axis_color := Color(1, 1, 1, 0.35)
var text_color := Color(1, 1, 1, 0.75)

var _swatch := ColorRect.new()
var _menu := OptionButton.new()
var _plot := Control.new()


func _ready() -> void:
	var header := HBoxContainer.new()
	add_child(header)
	_swatch.custom_minimum_size = Vector2(10, 10)
	_swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(_swatch)
	header.add_child(_menu)

	_plot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_plot.clip_contents = true
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_plot)

	_plot.draw.connect(_draw_plot)
	_plot.resized.connect(_plot.queue_redraw)
	_menu.item_selected.connect(_on_selected)
	rebuild_menu()


func refresh() -> void:
	_plot.queue_redraw()


func rebuild_menu() -> void:
	if not is_node_ready() or data == null:
		return
	_menu.clear()
	for k in data.series:
		if k == x_key:
			continue
		_menu.add_item(str(k))
		if k == key:
			_menu.select(_menu.item_count - 1)
	_swatch.color = _color()
	refresh()


## Change the series shown, without emitting key_changed (used by GraphStack for swaps).
func show_key(new_key: String) -> void:
	key = new_key
	rebuild_menu()


func _on_selected(index: int) -> void:
	var old := key
	key = _menu.get_item_text(index)
	_swatch.color = _color()
	refresh()
	if key != old:
		key_changed.emit(self, old, key)


func _color() -> Color:
	return stack.color_of(key) if stack != null else Color.WHITE


# --- Drawing -----------------------------------------------------------------

func _draw_plot() -> void:
	var font := get_theme_default_font()
	var full := Rect2(Vector2.ZERO, _plot.size)
	_plot.draw_rect(full, background)

	if data == null or data.count == 0 or not data.series.has(key):
		_plot.draw_string(font, Vector2(8, 8 + font_size), "No data",
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)
		return

	var ys: PackedFloat32Array = data.series[key]
	var n := ys.size()
	var has_x := data.series.has(x_key)
	var xs: PackedFloat32Array = data.series[x_key] if has_x else PackedFloat32Array()

	var x_mm := _min_max(xs) if has_x else Vector2(0.0, n - 1)
	var xa := _nice_axis(x_mm.x, x_mm.y, false, 5)          # (min, max, step)
	var y_mm := _min_max(ys)
	var ya := _nice_axis(y_mm.x, y_mm.y, y_from_zero, 3)

	var bottom := font_size + 10.0
	var r := Rect2(left_margin, 6.0,
			full.size.x - left_margin - right_margin, full.size.y - 6.0 - bottom)
	if r.size.x < 20.0 or r.size.y < 20.0:
		return

	_draw_grid(font, r, xa, ya)

	var col := _color()
	var sx := r.size.x / (xa.y - xa.x)
	var sy := r.size.y / (ya.y - ya.x)
	var step := maxi(1, ceili(float(n) / max_points))
	var seg := PackedVector2Array()
	var last_p := Vector2.ZERO
	var last_v := NAN

	var i := 0
	while true:
		var x := xs[i] if has_x else float(i)
		var y := ys[i]
		if is_nan(x) or is_nan(y):
			_flush(seg, col)                # gap: break the line
			seg = PackedVector2Array()
		else:
			var p := Vector2(r.position.x + (x - xa.x) * sx, r.end.y - (y - ya.x) * sy)
			seg.append(p)
			last_p = p
			last_v = y
		if i == n - 1:
			break
		i = mini(i + step, n - 1)           # downsample, but always reach the last sample
	_flush(seg, col)

	# Last value: dot at the end of the line + number in the right margin
	if not is_nan(last_v):
		_plot.draw_circle(last_p, 3.0, col)
		var ty := clampf(last_p.y, r.position.y + font_size * 0.5, r.end.y)
		_plot.draw_string(font, Vector2(r.end.x + 6.0, ty + font_size * 0.35), _fmt(last_v),
				HORIZONTAL_ALIGNMENT_LEFT, right_margin - 8.0, font_size + 1, col)


func _draw_grid(font: Font, r: Rect2, xa: Vector3, ya: Vector3) -> void:
	var ny := roundi((ya.y - ya.x) / ya.z)
	for i in ny + 1:
		var v := ya.x + i * ya.z
		var y := r.end.y - (v - ya.x) / (ya.y - ya.x) * r.size.y
		_plot.draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), grid_color)
		var t := _fmt(v)
		_plot.draw_string(font, Vector2(r.position.x - 6.0 - _text_w(font, t), y + font_size * 0.35),
				t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	var nx := roundi((xa.y - xa.x) / xa.z)
	for i in nx + 1:
		var v := xa.x + i * xa.z
		var x := r.position.x + (v - xa.x) / (xa.y - xa.x) * r.size.x
		_plot.draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), grid_color)
		var t := _fmt(v)
		_plot.draw_string(font, Vector2(x - _text_w(font, t) * 0.5, r.end.y + font_size + 3.0),
				t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	_plot.draw_rect(r, axis_color, false, 1.0)


func _flush(seg: PackedVector2Array, col: Color) -> void:
	if seg.size() >= 2:
		_plot.draw_polyline(seg, col, line_width, true)
	elif seg.size() == 1:
		_plot.draw_circle(seg[0], line_width, col)


# --- Helpers -----------------------------------------------------------------

func _min_max(arr: PackedFloat32Array) -> Vector2:
	var lo := INF
	var hi := -INF
	for v in arr:
		if is_nan(v):
			continue
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return Vector2(lo, hi)


## Rounds a range to "nice" tick values. Returns (min, max, step).
func _nice_axis(lo: float, hi: float, from_zero: bool, ticks: int) -> Vector3:
	if is_inf(lo) or is_inf(hi):
		return Vector3(0.0, 1.0, 0.25)
	if from_zero and lo > 0.0:
		lo = 0.0
	if hi - lo < 1e-9:
		hi += 1.0
		if not (from_zero and lo >= 0.0):
			lo -= 1.0
	var step := _nice_step((hi - lo) / ticks)
	return Vector3(floorf(lo / step) * step, ceilf(hi / step) * step, step)


func _nice_step(raw: float) -> float:
	var mag := pow(10.0, floorf(log(raw) / log(10.0)))
	var f := raw / mag
	if f <= 1.0: return mag
	if f <= 2.0: return 2.0 * mag
	if f <= 5.0: return 5.0 * mag
	return 10.0 * mag


func _fmt(v: float) -> String:
	var a := absf(v)
	if a >= 1e6:
		return "%.1fM" % (v / 1e6)
	if a >= 1e4:
		return "%.1fk" % (v / 1e3)
	if a >= 100.0 or is_equal_approx(v, roundf(v)):
		return "%d" % roundi(v)
	if a >= 10.0:
		return "%.1f" % v
	return "%.2f" % v


func _text_w(font: Font, t: String) -> float:
	return font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
