extends RichTextLabel



func _ready() -> void:
	# Monospace font so the columns line up
	var mono := SystemFont.new()
	mono.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "monospace"])
	add_theme_font_override("font", mono)


func display_performance(am_usec: float, world_usec: float, render_usec: float) -> void:
	var total_usec := am_usec + world_usec + render_usec
	text = "\n".join([
		"FPS %d" % Engine.get_frames_per_second(),
		"%9s %9s %9s %9s" % ["ALife", "World", "Render", "Total"],
		"%9s %9s %9s %9s" % [_ms(am_usec), _ms(world_usec), _ms(render_usec), _ms(total_usec)],
	])


func _ms(usec: float) -> String:
	return "%.2f ms" % (usec / 1000.0)

func _perf_line(name: String, usec: float) -> String:
	return "%-7s %6.2f ms" % [name, usec / 1000.0]
