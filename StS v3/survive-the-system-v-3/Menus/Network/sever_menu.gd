extends Control

var IP_ADDRESS = "127.0.0.1"
var PORT = 10000
var MAX_CLIENTS = 5
var alifemanager

var peer: ENetMultiplayerPeer

signal server_started

func _ready() -> void:
	print(get_path())
		#connect signal of connection with function
	multiplayer.peer_connected.connect(on_connection)
	multiplayer.peer_disconnected.connect(on_disconnection)
	alifemanager = get_parent().get_parent().get_node("Alife manager")
	

	#other potential signal on client only
	'multiplayer.connected_to_server
	multiplayer.connection_failed
	multiplayer.server_disconnected'
	#call_deferred("_on_button_pressed")


func _process(_delta: float) -> void:
	if peer:
		if multiplayer.is_server():
			var beastfps = alifemanager.get_node("beast_manager").FPS
			var grassfps = alifemanager.get_node("Grass_Manager").FPS
			var grassfps2 = alifemanager.get_node("Grass_Manager2").FPS

			$FPS.text ="Peer ID: " + str(multiplayer.get_unique_id())
			$FPS.text = $FPS.text +  "\nfps: " + str(Engine.get_frames_per_second()) 
			$FPS.text = $FPS.text +  " \t Beats_Time: " + str(beastfps) 
			$FPS.text = $FPS.text +  " \t Grass_Time: " + str(grassfps) 
			$FPS.text = $FPS.text +  " \t Grass2_Time: " + str(grassfps2) 


func _on_button_pressed() -> void:
	if peer:
		stop_server()
		$Button.text = "Start Server"
	else:
		start_server()
		$Button.text = "Disconnect Server"
		#hide()


func start_server():
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = peer
	$Label.text = $Label.text + "\nServer ONLINE"
	server_started.emit()
	
	GlobalSimulationParameter.simulation_speed = 20000
	await get_tree().create_timer(1).timeout
	GlobalSimulationParameter.simulation_speed = 1

func stop_server():
	if peer:
		peer.close()
		multiplayer.multiplayer_peer = null
		peer = null
		$Label.text = $Label.text + "\nServer OFFLINE"


func on_connection(id):
	$Label.text = $Label.text + "\n" + str(id) + " connected to server"



func on_disconnection(id):
	$Label.text = $Label.text + "\n" + str(id) + " disconnected to server"
	if id == null:
		pass
	else:
		if get_parent().get_parent().get_node("Alife manager").has_node(str(id)):
			get_parent().get_parent().get_node("Alife manager").get_node(str(id)).queue_free()
			get_parent().get_parent().get_node("Alife manager").erase(str(id))

	


func _on_line_edit_text_submitted(new_text: String) -> void:
	GlobalSimulationParameter.simulation_speed = float(new_text)


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		GlobalSimulationParameter.DEBUG_grass_sim = 1
	else:
		GlobalSimulationParameter.DEBUG_grass_sim = 0


func _on_port_text_changed(new_text: String) -> void:
	PORT = int(new_text)
