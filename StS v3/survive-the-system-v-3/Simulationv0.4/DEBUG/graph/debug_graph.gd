extends Control

var world : WorldManager
var alifemanager : AlifeManager
var render : AlifeRendererManager 
var simulation_manager : SimulationManager

# Called when the node enters the scene tree for the first time.

func init(graphdata):
	$Panel/ScrollContainer/Graphstack.data = graphdata

func update():
	$Panel/Label.text = str(alifemanager.global_entity_count)

	$Panel/ScrollContainer/Graphstack.refresh()


	
func _on_show_hide_button_pressed() -> void:
	var ishow :bool = $Panel.visible
	$Panel.visible = !ishow
	if ishow:
		$SHOW_HIDEButton.text = "Open Graph"
	else:
		$SHOW_HIDEButton.text = "Close"
