extends Control
#This Script deal with the debug settings of main parameter for the game
#we idea is to test quickly different world settings
#And also to assess ecosystem equilibrium

var world : WorldManager
var alifemanager : AlifeManager
var render : AlifeRendererManager 
var sim_manager :SimulationManager

@export var map : Control

#-------------------------

func init():
	$Panel/Alife.alifemanager = alifemanager
	$Panel/Alife.init()
	$Panel/worldsettings.setup(alifemanager,world,map)
	$Panel/Rendering.setup(alifemanager,world)

#--------------------


func _on_show_hide_button_pressed() -> void:
	var ishow :bool = $Panel.visible
	$Panel.visible = !ishow
	if ishow:
		$SHOW_HIDEButton.text = "Open Settings"
	else:
		$SHOW_HIDEButton.text = "Close"


#------------------------------------Button LINK----------------------------------------------------



func _on_button_1_toggled(toggled_on: bool) -> void:
	$Panel/Alife.visible = toggled_on
	#$simulation_UI/World.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$Panel/worldsettings.visible = false
		$Panel/Rendering.visible = false
		$Panel/choose_menu/Button_3.button_pressed = false
		$Panel/choose_menu/Button_2.button_pressed = false

func _on_button_2_toggled(toggled_on: bool) -> void:
	$Panel/worldsettings.visible = toggled_on
	#$simulation_UI/Alife.visible = false
	#$simulation_UI/Rendering.visible = false
	if toggled_on:
		$Panel/Alife.visible = false
		$Panel/Rendering.visible = false
		$Panel/choose_menu/Button_1.button_pressed = false
		$Panel/choose_menu/Button_3.button_pressed = false

func _on_button_3_toggled(toggled_on: bool) -> void:
	$Panel/Rendering.visible = toggled_on
		#$simulation_UI/World.visible = false
		#$simulation_UI/Alife.visible = false
	if toggled_on:
		$Panel/Alife.visible = false
		$Panel/worldsettings.visible = false
		$Panel/choose_menu/Button_1.button_pressed = false
		$Panel/choose_menu/Button_2.button_pressed = false




func _on_button_toggled(toggled_on: bool) -> void:
	render.activated = toggled_on # Replace with function body.
