extends Control
var myIP = "127.0.0.1"
var PORT = 10000
var isWorldReady = false
var MAX_CLIENTS = 5
var peer: ENetMultiplayerPeer


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func init():
	fetch_public_ip()
	isWorldReady = false
	$ButtonStart/Label.text = ""
	$ButtonStart.disabled = false
	$ButtonStart.text = "Host"
	$Return.show()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func fetch_public_ip() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_public_ip)
	http.request("https://api.ipify.org")

func _on_public_ip(_result, code, _headers, body: PackedByteArray) -> void:
	if code == 200:
		var public_ip := body.get_string_from_utf8()
		#print("Public IP: ", public_ip)
		myIP = public_ip
		$IP.text = myIP



func start_server():
	peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT, MAX_CLIENTS)
	multiplayer.multiplayer_peer = peer
	#$Label.text = $Label.text + "\nServer ONLINE"	

func _on_button_pressed() -> void:
	$Panel.hide()


func _on_button_help_pressed() -> void:
	$Panel.show()


func abort_connection() -> void:
	if peer != null:
		peer.close()      # cancels a pending attempt or disconnects if connected
	if multiplayer.multiplayer_peer == peer:
		multiplayer.multiplayer_peer = null
	peer = null



func _on_return_pressed() -> void:
	abort_connection()
	hide()

func on_simulation_ready():
	start_server()
	$ButtonStart/Label.text = "Simulation Ready"
	$ButtonStart.disabled = false
	$ButtonStart.text = "Play"
	isWorldReady = true


func _on_button_start_pressed() -> void:
	if isWorldReady:
		#hide()
		get_parent().hide()
		get_parent().client_started.emit()
		#just an ugly way to fix somthing here... to send last version of all alife status:
		get_parent().get_parent().get_parent().get_node("Alife manager").get_node("Grass_Manager2")._on_peer_connected(1)

	else:
		$Return.hide()
		$ButtonStart/Label.text = "Generating World..."
		$ButtonStart.disabled = true
		get_parent().simulation_started.emit()
		pass # Replace with function body.


func _on_port_text_changed(new_text: String) -> void:
	PORT = int(new_text)
