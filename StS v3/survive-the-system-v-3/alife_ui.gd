extends Control
class_name Alife_UI

var species :TESTDNA
var index :int = -1
var alifemanager : AlifeManager

func setup(sp:TESTDNA, i:int):
	species = sp
	index = i

func display_info():
	var text : String = ""
	text = "Species: %s" % species.name
	text += "\nIndex: %d" % index
	text += "\nActif: %d" % species.active_alife_array[index]
	text += "\nPosition: %v" % species.position_array[index]
	text += "\nEnergy: %d" % species.current_energy_array[index]
	text += "\nAlive: %d" % species.alive_array[index]
	text += "\nAge: %d" % species.current_age[index]
	text += "\nLife cycle: %d" % species.current_biomass[index]

	$RichTextLabel.text = text


func _process(delta: float) -> void:
	if species and index >= 0:
		display_info()
		move()

func move():

	var cam = get_viewport().get_camera_2d()
	if cam != null:
		var p: Vector3 = species.position_array[index]
		var world := Vector2(p.x, p.z)
		var screen_center := get_viewport().get_visible_rect().size * 0.5
		position = (world - cam.get_screen_center_position()) * cam.zoom + screen_center
		position += Vector2(10, -10) 
	

	cam = get_viewport().get_camera_3d()
	if cam != null:
		var world_pos: Vector3 = species.position_array[index]
		visible = not cam.is_position_behind(world_pos)
		if visible:
			position = cam.unproject_position(world_pos) + Vector2(10, -10)	

func _on_button_close_pressed() -> void:
	species.renderer3D.material_override.set_shader_parameter("selected_id", -1)

	queue_free()


func _on_button_pressed() -> void:
	species.renderer3D.material_override.set_shader_parameter("selected_id", -1)

	species.Remove_Life(index)  #Probably pending list is better #TODO
	queue_free()
