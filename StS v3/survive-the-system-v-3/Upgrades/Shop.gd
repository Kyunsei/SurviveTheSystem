extends Control
@export var possible_items: Array[ItemResource]
@export var shop_size: int = 5
@export var shop_item_scene: PackedScene 
var current_stock: Array = []
@onready var grid = $Panel/GridContainer


func _ready():
	generate_shop()
	populate_grid()
	print(current_stock)

func generate_shop():
	current_stock.clear()

	var pool = possible_items.duplicate()
	pool.shuffle()

	for i in range(shop_size):
		if pool.is_empty():
			break

		var item = pool.pop_back()
		var entry = {
		"item": item,
		"quantity": randi_range(1, item.Max_quantity_in_shop)
		}

		current_stock.append(entry)
		
		
		
		
func populate_grid():
	for child in grid.get_children():
		child.queue_free()

	for entry in current_stock:
		var item_instance = shop_item_scene.instantiate()
		item_instance.setup(entry["item"], entry["quantity"])
		grid.add_child(item_instance)
		#
		#
		#
		
		
