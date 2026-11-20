extends ScrollContainer

var world: WorldManager
var alifemanager: AlifeManager

func setup(al:AlifeManager,wrld:WorldManager):
	world =wrld
	alifemanager = al


func _on_field_toggled(toggled_on: bool) -> void:
	$"VBoxContainer/HBoxContainer3/3DGrid".setup(alifemanager.field_cell_size, world.size)
	$"VBoxContainer/HBoxContainer3/3DGrid".set_activated(toggled_on) 
	$"VBoxContainer/HBoxContainer3/3DGrid".current_layer = -1  # show only y layer 0; -1 shows all layers
		 
func _on_contact_toggled(toggled_on: bool) -> void:
	$VBoxContainer/HBoxContainer2/contact_3DGrid2.setup(alifemanager.cell_size, world.size)
	$VBoxContainer/HBoxContainer2/contact_3DGrid2.set_activated(toggled_on) 
	$VBoxContainer/HBoxContainer2/contact_3DGrid2.current_layer = -1  # show only y layer 0; -1 shows all layers
		 
