extends Control

var IP_ADDRESS = "127.0.0.1" #"158.41.57.177"
var PORT = 12345

var peer: ENetMultiplayerPeer

var isconnected = false

func _ready() -> void:
		#connect signal of connection with function
	#multiplayer.peer_connected.connect(on_connection)
	multiplayer.server_disconnected.connect(on_server_disconnected)
	multiplayer.connected_to_server.connect(on_client_connection)
	multiplayer.connection_failed.connect(on_connection_failed)


	connect_to_server(IP_ADDRESS, PORT)

func check_connection():
	if multiplayer.multiplayer_peer:
		match multiplayer.multiplayer_peer.get_connection_status():
			MultiplayerPeer.CONNECTION_CONNECTED:
				$Label_server.text = "Connected to server"
			MultiplayerPeer.CONNECTION_CONNECTING:
				$Label_server.text = "Connecting..."
			MultiplayerPeer.CONNECTION_DISCONNECTED:
				$Label_server.text = "Disconnected"


func _process(delta: float) -> void:
	pass
	check_connection()

func connect_to_server(IP_ADDRESS, PORT):
	peer = ENetMultiplayerPeer.new()
	peer.create_client(IP_ADDRESS, PORT)
	multiplayer.multiplayer_peer = peer
	$Label_server.text = "Connecting..."


func on_client_connection():
	pass
	$Label_server.text = "Connected to server"

func on_connection_failed():
	pass
	$Label_server.text = "Connection failed"



	
func on_server_disconnected():
	$Label_server.text = "Server OFFLINE"
	#print("here SERVER")
	connect_to_server(IP_ADDRESS, PORT)


func _on_button_play_pressed() -> void:
	get_tree().change_scene_to_file("res://main_game.tscn")
