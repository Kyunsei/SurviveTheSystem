extends Control

#THIS is setup in the option manager
var codex: ALIFE_CODEX
var alifemanager: AlifeManager
@export var spawnBox : ScrollContainer

func init():
	#codex = alifemanager.codex
	spawnBox.codex = alifemanager.codex
	spawnBox.alifemanager = alifemanager
	spawnBox.init()
	#spawnBox.refresh()

	
	


func _on_generate_pressed() -> void:
	_on_remove_all_pressed()
	alifemanager.init_default_species(alifemanager.world,alifemanager)


func _on_kill_all_pressed() -> void:
	for sp in alifemanager.species_array:
		for i in sp.entity_count:
			sp.alive_array[i] = 0



func _on_remove_all_pressed() -> void:
	for sp in alifemanager.species_array:
		for i in sp.entity_count:
			#sp.active_alife_array[i]=0
			sp.Remove_Life(i)
