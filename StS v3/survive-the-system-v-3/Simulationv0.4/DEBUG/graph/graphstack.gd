class_name GraphStack
extends VBoxContainer
## One graph per series, all with Time on X, stacked vertically.
## Each graph has a dropdown: picking a series that another graph shows SWAPS the two,
## so you can bring any series to the top to focus on it.
##
## Scene setup:
##   ScrollContainer                (Horizontal Scroll: Disabled)
##     VBoxContainer  <- this script (Size Flags Horizontal: Expand + Fill)
##
## Code:
##   $ScrollContainer/GraphStack.data = graph_data
##   # after each graph_data.add_sample(...):
##   $ScrollContainer/GraphStack.refresh()

@export var x_key := "Time"
@export var graph_height := 130.0
@export var y_from_zero := true
@export var palette := PackedColorArray([
	Color("4e79a7"), Color("f28e2b"), Color("e15759"), Color("76b7b2"),
	Color("59a14f"), Color("edc948"), Color("b07aa1"), Color("ff9da7"),
])

var data: GraphData:
	set(v):
		if data != null and data.keys_changed.is_connected(_sync):
			data.keys_changed.disconnect(_sync)
		_remove_all()
		data = v
		if data != null:
			data.keys_changed.connect(_sync)
		_sync()

var _graphs: Array[SeriesGraph] = []


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sync()


## Redraw every graph. Call after adding samples.
func refresh() -> void:
	for g in _graphs:
		g.refresh()


## Same color for a series in every graph.
func color_of(key: String) -> Color:
	if data == null:
		return Color.WHITE
	var i := 0
	for k in data.series:
		if k == x_key:
			continue
		if k == key:
			return palette[i % palette.size()]
		i += 1
	return Color.WHITE


## Creates a graph for each series that doesn't have one yet.
func _sync() -> void:
	if not is_node_ready() or data == null:
		return
	if data.series.is_empty():
		_remove_all()
		return

	var shown: Array[String] = []
	for g in _graphs:
		shown.append(g.key)

	for k in data.series:
		if k == x_key or shown.has(str(k)):
			continue
		var g := SeriesGraph.new()
		g.stack = self
		g.data = data
		g.key = str(k)
		g.x_key = x_key
		g.y_from_zero = y_from_zero
		g.custom_minimum_size.y = graph_height
		g.key_changed.connect(_on_graph_key_changed)
		add_child(g)
		_graphs.append(g)

	for g in _graphs:
		g.rebuild_menu()   # new series must appear in every dropdown


## A graph switched to new_key: the graph that was showing new_key takes old_key (swap).
func _on_graph_key_changed(graph: SeriesGraph, old_key: String, new_key: String) -> void:
	for g in _graphs:
		if g != graph and g.key == new_key:
			g.show_key(old_key)
			break


func _remove_all() -> void:
	for g in _graphs:
		g.queue_free()
	_graphs.clear()
