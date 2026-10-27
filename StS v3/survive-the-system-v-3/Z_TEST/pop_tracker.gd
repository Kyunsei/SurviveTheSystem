extends Control


var graph : Graph
var alifem : AlifeManager
var pop_data_set : Array[Array]
var gene_data_set : Array[Array]


func  _ready() -> void:
	graph = $Panel/ColorRect


func init (alm:AlifeManager):
	alifem =alm
	pop_data_set.resize(alifem.species_array.size())
	for sp in alifem.species_array.size():
		pop_data_set[sp] = [alifem.species_array[sp].entity_count]

func update():
	for sp in alifem.species_array.size():
		pop_data_set[sp].append(alifem.species_array[sp].entity_count)
	graph.data_set = pop_data_set
	graph.queue_redraw()
		


func _on_check_box_toggled(toggled_on: bool) -> void:
	$Panel/ColorRect.normalized = toggled_on
