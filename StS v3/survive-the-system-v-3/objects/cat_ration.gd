extends MeshInstance3D

@export var item_ressources : Item
#@onready var inventory = %Inventory

var isInit = false

func _process(delta: float) -> void:
	if GlobalSimulationParameter.SimulationStarted and isInit == false:
		isInit = true
		


func _on_area_3d_body_entered(body: Node3D) -> void:
	print("DESACTIVATED FOR NOW")
	return
	#print(inventory)
	#print(body.get_node("../Inventory"))
	if body.is_in_group("player"):
		add_to_player.rpc_id(1,body,int(body.name))
	else:
		pass

@rpc("any_peer","call_local")
func add_to_player(body,peer_id):
		var inventory = body.get_node("Player_HUD").get_node("Inventory")
		print(inventory)
		if inventory.add_item(inventory.prep_item(self),peer_id):
			print("Cat ration picked up")
			queue_free()
