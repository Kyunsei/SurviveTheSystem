class_name GraphData
extends RefCounted
## Stores time-aligned series for GraphPanel.
## Each add_sample() call appends ONE value to EVERY series, so index i is the same
## moment in all of them. That's what lets you plot any series against any other.
##
## Usage (e.g. every 0.5 s of simulation):
##   graph_data.add_sample({"Time": sim_time, "Grass": grass.entity_count, "Rabbit": rabbit.entity_count})

signal keys_changed   # a new series appeared -> GraphPanel rebuilds its menus

## When this many samples are reached, every other sample is dropped (the last one is
## always kept). Memory stays bounded and the whole run stays visible, just coarser.
var max_samples := 4000

var series := {}   # String -> PackedFloat32Array
var count := 0


func add_sample(values: Dictionary) -> void:
	var new_key := false
	for key in values:
		if not series.has(key):
			# Series that appears late: earlier samples are unknown (NaN = gap in the line)
			var arr := PackedFloat32Array()
			arr.resize(count)
			arr.fill(NAN)
			series[key] = arr
			new_key = true

	for key in series:
		var arr: PackedFloat32Array = series[key]
		arr.append(float(values.get(key, NAN)))   # missing this time -> gap
		series[key] = arr
	count += 1

	if count > max_samples:
		_decimate()
	if new_key:
		keys_changed.emit()


func clear() -> void:
	series.clear()
	count = 0
	keys_changed.emit()


func last_value(key: String) -> float:
	if not series.has(key) or count == 0:
		return NAN
	return series[key][count - 1]


## Keep every other sample, making sure the most recent one is kept.
func _decimate() -> void:
	for key in series:
		var src: PackedFloat32Array = series[key]
		var start := (src.size() - 1) % 2
		var dst := PackedFloat32Array()
		dst.resize((src.size() - 1 - start) / 2 + 1)
		for j in dst.size():
			dst[j] = src[start + j * 2]
		series[key] = dst
	count = (series.values()[0] as PackedFloat32Array).size() if not series.is_empty() else 0
