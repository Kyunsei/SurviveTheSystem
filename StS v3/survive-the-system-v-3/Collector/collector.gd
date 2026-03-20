extends Node3D

var Biomass_collected = 0
var max_biomass = 3000
var first_biomass_threshold = 50
var second_biomass_threshold = 200
var third_biomass_threshold = 1000
var fourth_biomass_threshold = 2000
var credit_gain = 0
@onready var spaceship: Node3D = $"../SPACESHIP"
var collecting = true
var timer_to_escape = int(91)
var safe_timer = int(6)
#var factor =  0.005
var factor =  5.0
var InsideBiomassInitHeight


var isWorldAccelerated = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	InsideBiomassInitHeight = 3.8
	update_label()
	


#@rpc("any_peer","call_local")
func interact(player):

	if collecting == true :
		#var grassmanager = player.get_parent().get_node("Grass_Manager2")
		var item_hold = player.item_hold
		var inventory = player.get_node("Player_HUD").get_node("Inventory")

		if item_hold != null:
				if item_hold.size() < 1:
					return
				print(item_hold.size())
				var grassmanager = player.get_parent().get_node("Grass_Manager2")
				#if item_hold["Data"] is Dictionary:
				var temp_duplicate_list = item_hold["Data"].duplicate()
				for  o in temp_duplicate_list:
					if o is Dictionary:
						if item_hold["Data"][0]["Species"] == Alifedata.enum_speciesID.ITEM:
							print("you try to give an item")
							return

						Biomass_collected += o["Biomass"]*factor
						update_label()
						inventory.remove_selected(int(player.name))
					else:
						Biomass_collected += grassmanager.current_biomass_array[o]*factor
						update_label()
						inventory.remove_selected(int(player.name))

			

		
		'for o in player.inventory:		
			Biomass_collected += player.inventory[o]["current_energy"]*factor
			#player.remove_from_inventory(o,1)'
		#player.inventory = {}
		#player.inventory_count = 0
		
	if Biomass_collected >= first_biomass_threshold and collecting == true:
		first_biomass_threshold +=100000
		credit_gain += 10
		print("First threshold reached")
		for p in player.get_parent().player_array:
			credit_player(p)
	if Biomass_collected >= second_biomass_threshold and collecting == true:
		second_biomass_threshold +=100000
		credit_gain += 10
		print("First threshold reached")
		for p in player.get_parent().player_array:
			credit_player(p)
	if Biomass_collected >= third_biomass_threshold and collecting == true:
		third_biomass_threshold +=100000
		credit_gain += 10
		print("First threshold reached")
		for p in player.get_parent().player_array:
			credit_player(p)
	if Biomass_collected >= fourth_biomass_threshold and collecting == true:
		fourth_biomass_threshold +=100000
		update_insideBiomass()
		credit_gain += 10
		print("First threshold reached")
		for p in player.get_parent().player_array:
			credit_player(p)
	if Biomass_collected >= max_biomass and collecting == true:
		collecting = false
		print("BRAVO")
		#var c = 0
		#spaceship.get_node("Collector_ship").go_down()
		update_insideBiomass()
		#.go_down.rpc_id(1)
		#start_escape_phase(player)
		#for i in player.get_parent().player_array:
			#i.escape_fast_or_die.rpc_id(int(i.name))
			#i.go_back_to_ship.rpc_id(int(i.name),c)
			#set_world_readiness.rpc(false)
			#c +=1
			#GlobalSimulationParameter.simulation_speed = 0.5
			#credit_player(i)



		#end_of_quest.rpc_id(int(player.name),player)
	#p.grass_in_inventory = 0
	#print ("item collected")
	#print (Biomass_collected)'

func start_escape_phase(player):
	var collector_ship = spaceship.get_node("Collector_ship")
	$collected_amount_Label3D.text = "Collector is full and awaiting retrieval"
	stop_go_button()
	for p in player.get_parent().player_array:
		p.show_escape_timer.rpc_id(int(p.name), timer_to_escape)
		p.start_escape_ui.rpc_id(int(p.name), timer_to_escape) # shows UI timer

	var remaining_time = timer_to_escape

	while remaining_time > 0:
		await get_tree().create_timer(1.0).timeout
		remaining_time -= 1
		


		if collector_ship.global_position.y >= 90 and remaining_time > safe_timer:
			remaining_time = safe_timer
			for p in player.get_parent().player_array:
				p.force_escape_time.rpc_id(int(p.name), safe_timer)
	collecting = true
	Biomass_collected = 0
	max_biomass += 50
	max_biomass *= 1.5
	update_label()
	check_escape_results(player)
	

func check_escape_results(player):
	spaceship.get_node("Collector_ship").go_up()
	
	for p in player.get_parent().player_array:
		credit_player(p)
		p.stop_escape_ui.rpc()
		if p.position.y >= 90:
			p.escape_success.rpc_id(int(p.name))
		else:
			p.Die.rpc_id(int(p.name), int(p.name))
	Start_time_wrap()



func stop_go_button():
	spaceship.get_node("go_button").currently_active = true
func start_go_button():
	spaceship.get_node("go_button").currently_active = false

@rpc("any_peer","call_remote")
func end_of_quest(player):
	player.go_back_to_ship()
	
@rpc("any_peer","call_remote")
func set_world_readiness(yesorno):
		GlobalSimulationParameter.WorldReady = yesorno


func update_label():
	$collected_amount_Label3D.text = "Biomass collected " + str(int(round(Biomass_collected))) + " /" + str(int(round(max_biomass)))
	update_insideBiomass()

func update_insideBiomass():
	var fill_percentage = clamp(Biomass_collected/max_biomass, 0.0, 1.0)
	$InsideMesh.scale.y = fill_percentage
	var natural_offset = -3.7  + InsideBiomassInitHeight*fill_percentage#natural offset
	$InsideMesh.position.y = (natural_offset + (InsideBiomassInitHeight*fill_percentage))/2

#@rpc("any_peer","call_local")
func credit_player(player):
	player.catnation_credits += credit_gain 
	player.lifedata["Money"] = player.catnation_credits




func _process(_delta: float) -> void:
	if multiplayer.is_server():
		if isWorldAccelerated:
			if get_parent().get_node("Alife manager").get_node("Grass_Manager2").Grass_simulator_time <0 :
				GlobalSimulationParameter.simulation_speed = 1
				#get_parent().get_parent().get_node("Grass_Manager2").Grass_simulator_time = 2000 
				isWorldAccelerated = false 
				for p in get_parent().get_node("Alife manager").player_array:
					p.get_parent().get_node("Grass_Manager2").send_full_state_to_peer(int(p.name))
				start_go_button()

func Start_time_wrap():
	change_server_simulation_speed(600)

		

@rpc("any_peer","call_remote")
func change_server_simulation_speed(value):
	if isWorldAccelerated == false:
		get_parent().get_node("Alife manager").get_node("Grass_Manager2").Grass_simulator_time = 500
		GlobalSimulationParameter.simulation_speed = value
		isWorldAccelerated = true
