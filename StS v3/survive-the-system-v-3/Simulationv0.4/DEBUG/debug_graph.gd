extends Control

var world : WorldManager
var alifemanager : AlifeManager
var render : AlifeRendererManager 

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	$Panel/Label.text = str(alifemanager.global_entity_count)
	
func _on_show_hide_button_pressed() -> void:
	var ishow :bool = $Panel.visible
	$Panel.visible = !ishow
	if ishow:
		$SHOW_HIDEButton.text = "Open Graph"
	else:
		$SHOW_HIDEButton.text = "Close"
