extends MeshInstance3D

@export var item_ressources : Item
#@onready var inventory = %Inventory


func _on_area_3d_body_entered(body: Node3D) -> void:
	print("DESACTIVATED FOR NOW")
	return
	#print(inventory)
	#print(body.get_node("../Inventory"))
	if body.is_in_group("player"):
		var inventory = body.get_node("Player_HUD").get_node("Inventory")
		print(inventory)
		if inventory.add_item(inventory.prep_item(self),int(body.name)):
			print("Cat ration picked up")
			queue_free()
	else:
		pass
