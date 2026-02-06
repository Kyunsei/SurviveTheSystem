extends Node

var IP_ADDRESS = "127.0.0.1" #"158.41.57.177"
var PORT = 12345
var MAX_CLIENTS = 5

var peer: ENetMultiplayerPeer


func _ready() -> void:
	print(get_path())
		#connect signal of connection with function
	multiplayer.peer_connected.connect(on_connection)
	multiplayer.peer_disconnected.connect(on_disconnection)

	#other potential signal on client only
	'multiplayer.connected_to_server
	multiplayer.connection_failed
	multiplayer.server_disconnected'
	#call_deferred("_on_button_pressed")


func _on_button_pressed() -> void:
	print("hello")
	if peer:
		stop_server()
		$Button.text = "Start Server"
	else:
		start_server()
		$Button.text = "Disconnect Server"


func start_server():
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = peer
	$Label.text = $Label.text + "\nServer ONLINE"

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
	
