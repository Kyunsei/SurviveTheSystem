extends ColorRect


var posx = 0
var posy = 0
var current_value = [0,0,0,0,0,0,0,0,0,0]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	if valueChangedAbovethresold(2):
		color = getBlockColor()
		
	$Label.text = str("%.1f" %World.Block_Matrix[posx*World.worldsize*World.numberElement+posy*World.numberElement])


func setDebug(string):
	$Label.text = string

func getBlockColor():
	#var b_element =[]
	var color = Color(0, 0, 0)
	var valueR = 0
	var valueG = 0
	var valueB = 0
	var count = 0
	var size = World.element_state.size()
	for e in range(World.element_state.size()):
		if World.visibleElementToggle[e]:
			color = World.color_mapping.get(e, Color(0, 0, 0))	
			valueR += min(color.r, color.r * World.Block_Matrix[posx*World.worldsize*World.numberElement+posy*World.numberElement + e])
			valueG += min(color.g, color.g * World.Block_Matrix[posx*World.worldsize*World.numberElement+posy*World.numberElement + e])
			valueB += min(color.b, color.b * World.Block_Matrix[posx*World.worldsize*World.numberElement+posy*World.numberElement + e])
			'var value = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + e]
			var value2 = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + 1]
			var value3 = World.Block_Matrix[i*World.worldsize*stone_element.size()+j*stone_element.size() + 2]
			color = Color(value/10,value2/10,value3/10)'
			count += 1
	if count >0:
		color = Color(valueR,valueG,valueB)
	#print("final color :" + str(color))
	return color
	
func valueChangedAbovethresold(thrshld):
	var newvalue = 0
	var isit = false
	for e in range(World.numberElement):
		newvalue = World.Block_Matrix[posx*World.worldsize*World.numberElement+posy*World.numberElement + e]
		if abs(newvalue - current_value[e]) > thrshld:
			isit = true
			current_value[e] = newvalue
	return isit
	
