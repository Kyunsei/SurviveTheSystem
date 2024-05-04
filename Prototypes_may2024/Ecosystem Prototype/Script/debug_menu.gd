extends Control

var ID = 0
# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_button_pressed():
	hide()
	get_parent().get_node("DebugWindowButton").show() # Replace with function body.


func _on_color_color_changed(color):
	World.color_mapping[ID] = color # Replace with function body.


func _on_id_value_changed(value):
	ID = int(value)
	$GridContainer/IDtext.text = str(ID)
	$GridContainer/Color.color = World.color_mapping[ID]
	$GridContainer/Range.text = str(World.element_flow_btw_min[ID])
	$GridContainer/Speed.value = World.element_flow_btw[ID]


func _on_speed_value_changed(value):
	World.element_flow_btw[ID]= value # Replace with function body.



func _on_speed_text_changed(new_text):
	World.element_flow_btw[ID]= int(new_text) # Replace with function body.


func _on_range_text_changed(new_text):
	World.element_flow_btw_min[ID]= int(new_text) # Replace with function body.


func changeDisplay(index, value):
	World.visibleElementToggle[index]= value

func CreateElement(index, value):
	World.createElementToggle[index]= value


func _on_ID1_toggled(toggled_on):
	changeDisplay(0, toggled_on)
	
func _on_ID2_toggled(toggled_on):
	changeDisplay(1, toggled_on)

func _on_ID3_toggled(toggled_on):
	changeDisplay(2, toggled_on)

func _on_ID4_toggled(toggled_on):
	changeDisplay(3, toggled_on)

func _on_ID5_toggled(toggled_on):
	changeDisplay(4, toggled_on)

func _on_ID6_toggled(toggled_on):
	changeDisplay(5, toggled_on)

func _on_ID7_toggled(toggled_on):
	changeDisplay(6, toggled_on)

func _on_ID8_toggled(toggled_on):
	changeDisplay(7, toggled_on)

func _on_ID9_toggled(toggled_on):
	changeDisplay(8, toggled_on)

func _on_ID10_toggled(toggled_on):
	changeDisplay(9, toggled_on)



func _on_create1_toggled(toggled_on):
	CreateElement(0, toggled_on)

func _on_create2_toggled(toggled_on):
	CreateElement(1, toggled_on)

func _on_create3_toggled(toggled_on):
	CreateElement(2, toggled_on)
	
func _on_create4_toggled(toggled_on):
	CreateElement(3, toggled_on)

func _on_create5_toggled(toggled_on):
	CreateElement(4, toggled_on)


