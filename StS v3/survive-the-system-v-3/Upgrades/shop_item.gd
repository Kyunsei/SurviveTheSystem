extends Button


var item_resource: ItemResource
var quantity: int
var id_in_stock
var image
var quantity_label 
var itemz
var prizez
var Shop_area
var price_label
var Alife_manager 
var itemz_path 
var item_spawn_position

func setup(peer_id, item: ItemResource, qty: int, id):
	
	itemz= item
	image = $TextureRect
	quantity_label = $Quantity 
	price_label =$Price
	#$TextureRect.texture =textur
	item_resource = item
	quantity = qty
	id_in_stock = id

	#if item.inventory_icon:
	image.texture = item.inventory_icon
	prizez = item.Price
	itemz_path = item.item_path
	if quantity:
		quantity_label.text = str("In stock: ") + str(quantity)
	if item.Price :
		price_label.text = str("Price: ")+str(item.Price)
		
	var path = item.resource_path
	setup_client.rpc_id(peer_id,path,qty,id)

@rpc("any_peer","call_local")
func setup_client(item_path, qty: int,id):
	var item = load(item_path)
	itemz= item
	image = $TextureRect
	quantity_label = $Quantity 
	price_label =$Price
	#$TextureRect.texture =textur
	item_resource = item
	quantity = qty
	id_in_stock = id
	#if item.inventory_icon:
	image.texture = item.inventory_icon
	prizez = item.Price
	itemz_path = item.item_path
	if quantity != null:
		quantity_label.text = str("In stock: ") + str(quantity)
	if item.Price  != null:
		price_label.text = str("Price: ")+str(item.Price)

@rpc("any_peer","call_local")
func _on_pressed() -> void:
	if quantity > 0 :
		Shop_area = get_parent().get_parent().get_parent().get_parent().get_parent()
		#Alife_manager =  get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_node("Alife manager")
		#if check_money.rpc_id(1, Shop_area.local_p_id, itemz.price) == true:
		
		buy_item.rpc_id(1, multiplayer.get_unique_id(), prizez, itemz_path)
			#quantity -= 1
			#quantity_label.text = str(quantity)

@rpc("any_peer","call_remote")
func buy_item(id, price, path):
	#var sender_id = multiplayer.get_remote_sender_id()
	Shop_area = get_parent().get_parent().get_parent().get_parent().get_parent()
	var shop =  get_parent().get_parent().get_parent()
	Alife_manager =  get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_node("Alife manager")
	item_spawn_position= Shop_area.global_position
	for p in Alife_manager.player_array :
			#print(p.name)
			#print(str(id))
		if p.name == str(id) :
			if p.catnation_credits >= price:

				Alife_manager.get_node("Item_Manager").spawn_new_item(path,item_spawn_position)
				p.catnation_credits -= price
				shop.current_stock[id_in_stock]["quantity"] -=1
				#quantity -= 1
				change_quantity.rpc_id(id)

@rpc("any_peer","call_remote")
func change_quantity():
	quantity -= 1
	quantity_label.text = str("In stock: ") + str(quantity)
	
	
	

			
			
			
