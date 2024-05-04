extends Node

#variable to move elsewhere




var life_entities = []
var day = 0
var init=false
# Called when the node enters the scene tree for the first time.

var PlayerInitPos = Vector2(0,0)


func _ready():
	$Timer.wait_time = 1 / World.World_Speed
	#print(World.worldsize)
	$Life_entities/Player.position = Vector2(World.worldsize,World.worldsize)*World.tile_size/2
	#$Tool.position = $Life_entities/Player.position + Vector2(World.tile_size*2,0)
	$World_elements.InstantiateAround($Life_entities/Player.position)
	#$Life_entities.InstantiateAround($Life_entities/Player.position)
	$Life_entities.InstantiateAll()
	PlayerInitPos = $Life_entities/Player.position
	


func countLife():
	World.grass_number = 0
	World.berry_number = 0
	World.meat_number = 0
	World.Life_Energy = 0
	World.Soil_Energy = 0
	World.Total_Energy = 0
	for l in $Life_entities.get_children():
		if l.is_in_group("Life"):
			World.Life_Energy += l.energy
			if l.parameters.foodtype=="grass":
				World.grass_number += 1
			if l.parameters.foodtype=="berry":
				World.berry_number+=1
			if l.parameters.foodtype=="meat":
				World.meat_number+=1

	World.Total_Energy = World.Soil_Energy + World.Life_Energy 
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	if PlayerInitPos.distance_to($Life_entities/Player.position)/World.tile_size > 1:
		$World_elements.RemoveOutScreenInstantiatedBlock($Life_entities/Player.position,2)
		$World_elements.instantiateBlockClose($Life_entities/Player.position, $Life_entities/Player.input_dir,2)
		$Life_entities.DeleteOutofScreen($Life_entities/Player.position,2)
		
		$Life_entities.instantiateClose($Life_entities/Player.position, $Life_entities/Player.input_dir,2)
		PlayerInitPos = $Life_entities/Player.position


			

	#$World_elements.instantiateBlockClose($Life_entities/Player.position)
#	if $Life_entities/Player.input_dir != Vector2(0,0) and updated == false:
#		$World_elements.instantiateClose($Life_entities/Player.position, $Life_entities/Player.input_dir)

		#$World_elements.UpdateAllInstantiateBlock()
	#countLife()
	#$World_elements.UpdateAllInstantiateBlock()
	$Panel/WorldInfo.text ="\nSun: " + str(World.day) + "\n grass:" + str(World.grass_number) + "\n berry:" + str(World.berry_number) + "\n meat:" + str(World.meat_number)
	$Panel/FPS.text = str(Engine.get_frames_per_second()) + " FPS"
	#$Panel/WorldEnergyInfo.text = "Soil energy:" + str("%.2f" % World.Soil_Energy) + "\n Life energy:" + str("%.2f" % World.Life_Energy) + "\n Tenergy:" + str("%.2f" % World.Total_Energy)
	#$World_elements.InstantiateAround($Life_entities/Player.position)
	if Input.is_action_pressed("dash"):

		#$Life_entities.InstantiateAround($Life_entities/Player.position)
		pass

'		countLife()
		for t in World.Block_to_update:
			$World_elements.UpdateInstantiateBlock(t[0],t[1])
	'

func _on_timer_timeout():

	$World_elements.FromSphereToBlocksGPU()


	$Life_entities.LifeGPU()
	
	$World_elements.UpdateAllInstantiateBlock()
	
	$Life_entities.DuplicateLife()
	$Life_entities.DeleteLife()
	

	#$Life_entities.UpdateAllInstantiateLife()
	


'''
func UpdateLife():
	var death_index = []
	if life_entities.size()>0:
		for i in life_entities.size():
			var l= life_entities[i]
			if l.reproduce == true:
				InitLife()
				l.reproduce = false
			if l.death == true:
				death_index.append(i)
				World.Soil_food += l.energyReproductionCost
				
		for i in death_index:
			life_entities[i].queue_free()
			life_entities.remove_at(i)
'''			
				



func UpdateSimulationSpeed():
	$Timer.wait_time = 1 / World.World_Speed
	$Timer.start(0)
	#$World_elements.UpdateSimulationSpeed()

'	$daynight.UpdateSimulationSpeed()

	var lifes = $Life_entities.get_children()
	for l in lifes:
		l.UpdateSimulationSpeed()'



func _on_h_scroll_bar_value_changed(value):
	World.World_Speed= value 
	UpdateSimulationSpeed()
	$Panel/SpeedScroll/Label.text = "Speed: " + str(value)



func _on_debug_window_button_pressed():
	$Panel/DebugMenu.show() # Replace with function body.
	$Panel/DebugWindowButton.hide()
