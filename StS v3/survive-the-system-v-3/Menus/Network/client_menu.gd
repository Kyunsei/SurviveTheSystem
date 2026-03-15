extends Control

var IP_ADDRESS = "127.0.0.1"
var Local_address = "127.0.0.1"
var V_address ="" 
var K_address = ""
var newIP = ""
#var tried_already = false
var PORT = 10000

var peer: ENetMultiplayerPeer

var isconnected = false

signal client_started

func _ready() -> void:
		#connect signal of connection with function
	#multiplayer.peer_connected.connect(on_connection)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer.connected_to_server.connect(on_client_connection)
	multiplayer.connection_failed.connect(on_connection_failed)


	#connect_to_server(IP_ADDRESS, PORT)

func check_connection():
	if multiplayer.multiplayer_peer:
		match multiplayer.multiplayer_peer.get_connection_status():
			MultiplayerPeer.CONNECTION_CONNECTED:
				$Label_server.text = "Connected to server"
			MultiplayerPeer.CONNECTION_CONNECTING:
				$Label_server.text = "Connecting..."
			MultiplayerPeer.CONNECTION_DISCONNECTED:
				$Label_server.text = "Disconnected"


func _process(_delta: float) -> void:
	pass
	#check_connection()

func connect_to_server(IP_ADDRESSv, PORTv):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESSv, PORTv)
	multiplayer.multiplayer_peer = peer
	$Label_server.text = "Connecting..."


func on_client_connection():
	pass
	$Label_server.text = "Connected to server"
	$VBoxContainer/Button_Play.disabled = false

func on_connection_failed():
	'if tried_already == false:
		newIP =V_address
		connect_to_server(newIP, PORT)
	else:
		pass'
	$Label_server.text = "Connection failed"
	$VBoxContainer/Button_Play.disabled = true


	
func on_server_disconnected():
	$Label_server.text = "Server OFFLINE"
	$VBoxContainer/Button_Play.disabled = true
	show()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#print("here SERVER")
	connect_to_server(IP_ADDRESS, PORT)


func _on_button_play_pressed() -> void:
	hide()
	client_started.emit()
	#get_tree().change_scene_to_file("res://main_game.tscn")




func _on_button_localconnect_pressed() -> void:
	connect_to_server(Local_address, PORT)


func _on_button_onlineconnect_pressed() -> void:
	newIP =K_address
	connect_to_server(newIP, PORT)


func _on_button_onlineconnect_2_pressed() -> void:
	newIP =V_address
	connect_to_server(newIP, PORT)


func _on_button_online_pressed() -> void:
	print(IP_ADDRESS)
	print(PORT)
	connect_to_server(IP_ADDRESS, PORT)


func _on_port_text_changed(new_text: String) -> void:
	PORT = int(new_text)


func _on_ip_text_changed(new_text: String) -> void:
	IP_ADDRESS = new_text


func _on_button_quit_pressed() -> void:
	get_tree().quit()
