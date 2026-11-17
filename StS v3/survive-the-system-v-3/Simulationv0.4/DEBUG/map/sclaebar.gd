class_name ColorScaleBar
extends Control
## Vertical color scale (legend) for a map whose alpha goes from 0 (value 0) to 1 (max_value).
## Bar on the left, tick labels on the right. Set `max_value` whenever the map updates.

@export var color := Color(1.0, 0.8, 0.1)       # same color as the map
@export var background := Color.BLACK           # what the map shows where alpha = 0
@export var max_value := 1.0:
	set(v):
		if v == max_value:
			return
		max_value = v
		queue_redraw()
@export var unit := ""                           # e.g. "J", "%", "lux"
@export_range(1, 10) var ticks := 4
@export var bar_width := 16.0
@export var font_size := 11
@export var text_color := Color(1, 1, 1, 0.8)
@export var title := ""                          # optional label above the bar


func _ready() -> void:
	resized.connect(queue_redraw)
	custom_minimum_size.x = maxf(custom_minimum_size.x, bar_width + 60.0)


func _draw() -> void:
	var font := get_theme_default_font()
	var top_margin := font_size + 6.0 if title != "" else font_size * 0.5
	var bar := Rect2(0.0, top_margin, bar_width, size.y - top_margin - font_size * 0.5)
	if bar.size.y <= 0.0:
		return

	if title != "":
		draw_string(font, Vector2(0.0, font_size), title,
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)

	# Background, then the gradient: top = max (alpha 1), bottom = 0 (alpha 0)
	draw_rect(bar, background)
	var top_col := color
	var bottom_col := Color(color, 0.0)
	draw_polygon(
		PackedVector2Array([
			bar.position,
			Vector2(bar.end.x, bar.position.y),
			bar.end,
			Vector2(bar.position.x, bar.end.y),
		]),
		PackedColorArray([top_col, top_col, bottom_col, bottom_col]))
	draw_rect(bar, Color(text_color, 0.4), false, 1.0)

	# Ticks + labels
	var half_text := font.get_ascent(font_size) * 0.4
	for k in ticks + 1:
		var t := float(k) / ticks
		var y := lerpf(bar.end.y, bar.position.y, t)
		draw_line(Vector2(bar.end.x, y), Vector2(bar.end.x + 4.0, y), Color(text_color, 0.6))
		draw_string(font, Vector2(bar.end.x + 7.0, y + half_text), _format(max_value * t),
				HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color)


func _format(v: float) -> String:
	var s: String
	if absf(max_value) >= 100.0:
		s = "%d" % roundi(v)
	elif absf(max_value) >= 10.0:
		s = "%.1f" % v
	else:
		s = "%.2f" % v
	return s + (" " + unit if unit != "" else "")
