extends Control

var IP_ADDRESS = "127.0.0.1"
var PORT = 10000
var MAX_CLIENTS = 5
var alifemanager

var peer: ENetMultiplayerPeer
var is_screen_focus

signal server_started
signal simulation_started

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
	var thread_count := OS.get_processor_count()
	var cpu_name := OS.get_processor_name()
	print("Threads: ", thread_count, " CPU: ", cpu_name)
	var rd := RenderingServer.create_local_rendering_device()
	if rd:
		print("Device: ", rd.get_device_name(), " / ", rd.get_device_vendor_name())
		print("API: ", RenderingServer.get_video_adapter_api_version())
		print("Max compute workgroup size: ",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_SIZE_X), "x",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_SIZE_Y), "x",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_SIZE_Z))
		print("Max invocations per workgroup: ",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_INVOCATIONS))
		print("Max workgroups: ",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_COUNT_X), "x",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_COUNT_Y), "x",
			rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_WORKGROUP_COUNT_Z))
		print("Max shared memory: ", rd.limit_get(RenderingDevice.LIMIT_MAX_COMPUTE_SHARED_MEMORY_SIZE))
		rd.free()
func _process(_delta: float) -> void:
	#if peer:
	if multiplayer.is_server():
			var beastfps = alifemanager.get_node("beast_manager").FPS
			#var grassfps = alifemanager.get_node("Grass_Manager").FPS
			var grassfps2 = alifemanager.get_node("Grass_Manager2").FPS
			var grassworld2 = alifemanager.get_node("Grass_Manager2").FPS_World


			$FPS.text ="Peer ID: " + str(multiplayer.get_unique_id())
			$FPS.text = $FPS.text +  "nThreads: " + str(OS.get_processor_count()) +" " + str(WorkerThreadPool)
			$FPS.text = $FPS.text +  "\nfps: " + str(Engine.get_frames_per_second()) 
			$FPS.text = $FPS.text +  " \t Beast_Time: " + str(beastfps) 
			$FPS.text = $FPS.text +  " \t World_Time: " + str(grassworld2) 
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
			var p = get_parent().get_parent().get_node("Alife manager").get_node(str(id))
			get_parent().get_parent().get_node("Alife manager").player_array.erase(p)
			get_parent().get_parent().get_node("Alife manager").get_node("Grass_Manager2").Kill_Grass(p.alifemanager_id)
			p.queue_free()


func _input(event: InputEvent) -> void:
	if multiplayer.multiplayer_peer and multiplayer.is_server():
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode == 35:
				visible = not visible
				if visible:
					var p = get_parent().get_parent().get_node("Alife manager").get_node(str(1))
					if p:
						p.hide_inventory()
					$WorldVisualisation.isOn = true
					Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # free the cursor for the UI
				else:
					if GlobalSimulationParameter.ClientStarted:
						$WorldVisualisation.isOn = false
						var p = get_parent().get_parent().get_node("Alife manager").get_node(str(1))
						if p:
							p.show_inventory()
						Input.mouse_mode = Input.MOUSE_MODE_CAPTURED  # back to gameplay


func _on_line_edit_text_submitted(new_text: String) -> void:
	GlobalSimulationParameter.simulation_speed = float(new_text)


func _on_check_button_toggled(toggled_on: bool) -> void:
	if toggled_on:
		GlobalSimulationParameter.DEBUG_grass_sim = 1
	else:
		GlobalSimulationParameter.DEBUG_grass_sim = 0


func _on_port_text_changed(new_text: String) -> void:
	PORT = int(new_text)


func _on_button_simulation_pressed() -> void:
	GlobalSimulationParameter.server_ready = true
