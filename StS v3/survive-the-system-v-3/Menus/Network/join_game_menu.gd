extends Control

var IP_ADDRESS ="127.0.0.1"# "192.168.0.1"#"127.0.0.1"
var PORT = 10000
var peer: ENetMultiplayerPeer

var isConnected = false
signal client_started

func _ready() -> void:
		#connect signal of connection with function
	#multiplayer.peer_connected.connect(on_connection)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer.connected_to_server.connect(on_client_connection)
	multiplayer.connection_failed.connect(on_connection_failed)

func init():
	$ButtonStart.disabled = false
	$ButtonStart/Label.text = ""
	$ButtonStart.text = "Connect"


func check_connection():
	#NOT IN USE
	if multiplayer.multiplayer_peer:
		$ButtonStart.disabled = true
		match multiplayer.multiplayer_peer.get_connection_status():
			MultiplayerPeer.CONNECTION_CONNECTED:
				$ButtonStart/Label.text = "Connected to server"
			MultiplayerPeer.CONNECTION_CONNECTING:
				$ButtonStart/Label.text = "Connecting..."
			MultiplayerPeer.CONNECTION_DISCONNECTED:
				$ButtonStart/Label.text = "Disconnected"


@rpc("any_peer","call_local")
func get_server_readiness():
	set_server_readiness.rpc(GlobalSimulationParameter.server_ready) 

@rpc("any_peer","call_local")
func set_server_readiness(v):
	GlobalSimulationParameter.server_ready = v


func on_client_connection():
	pass
	$ButtonStart/Label.text = "Connected to server"
	isConnected = true
	#get_server_readiness.rpc_id(1)
	#if GlobalSimulationParameter.server_ready:
		#$VBoxContainer/Button_Play.disabled = false
	$ButtonStart.text = "Play"
	$ButtonStart.disabled = false



func on_connection_failed():
	'if tried_already == false:
		newIP =V_address
		connect_to_server(newIP, PORT)
	else:
		pass'
	$ButtonStart/Label.text = "Connection failed"
	isConnected = false
	$ButtonStart.text = "Connect"
	$ButtonStart.disabled = false


func on_server_disconnected():
	$ButtonStart/Label.text = "Server OFFLINE"
	isConnected = false	
	$ButtonStart.disabled = false
	$ButtonStart.text = "Connect"
	GlobalSimulationParameter.server_ready = false
	get_parent().show()
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#connect_to_server(IP_ADDRESS, PORT)

func connect_to_server(IP_ADDRESSv, PORTv):
	peer = ENetMultiplayerPeer.new()
	print(IP_ADDRESSv,PORTv)
	peer.create_client(IP_ADDRESSv, PORTv)
	multiplayer.multiplayer_peer = peer
	$ButtonStart/Label.text = "Connecting..."
	$ButtonStart.disabled = true



func abort_connection() -> void:
	if peer != null:
		peer.close()      # cancels a pending attempt or disconnects if connected
	if multiplayer.multiplayer_peer == peer:
		multiplayer.multiplayer_peer = null
	peer = null

func _on_return_pressed() -> void:
	abort_connection()
	hide()


func _on_ip_text_changed(new_text: String) -> void:
	IP_ADDRESS = new_text


func _on_port_text_changed(new_text: String) -> void:
	PORT = int(new_text)


func _on_button_start_pressed() -> void:
	if isConnected:
		get_parent().hide()
		get_parent().client_started.emit()
	else:
		connect_to_server(IP_ADDRESS,PORT)
