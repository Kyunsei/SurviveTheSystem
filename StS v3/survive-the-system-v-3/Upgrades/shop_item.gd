extends Button


var item_resource: ItemResource
var quantity: int

var image
var quantity_label 
var itemz
var prizez
var Shop_area
var price_label
var Alife_manager 
const CAT_RATION = "res://objects/cat_ration/cat_ration.tscn"
const SPEARAXE = "res://objects/cat_ration/Object_spear.tscn"
const VACUUM = "res://objects/cat_ration/Object_Vacuum.tscn"
var itemz_path 
var item_spawn_position

func _ready():
	Shop_area = get_parent().get_parent().get_parent().get_parent().get_parent()
	Alife_manager =  get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_parent().get_node("Alife manager")
	item_spawn_position= Shop_area.global_position
	pass
func setup(item: ItemResource, qty: int):
	itemz= item
	image = $TextureRect
	quantity_label = $Quantity 
	price_label =$Price
	#$TextureRect.texture =textur
	item_resource = item
	quantity = qty
	#if item.inventory_icon:
	image.texture = item.inventory_icon
	prizez = item.Price
	itemz_path = item.item_path
	if quantity:
		quantity_label.text = str("In stock: ") + str(quantity)
	if item.Price :
		price_label.text = str("Price: ")+str(item.Price)


@rpc("any_peer","call_local")
func _on_pressed() -> void:
	if quantity > 0 :
		#if check_money.rpc_id(1, Shop_area.local_p_id, itemz.price) == true:
			buy_item.rpc_id(1, Shop_area.local_p_id, prizez)
			#quantity -= 1
			#quantity_label.text = str(quantity)

@rpc("any_peer","call_remote")
func buy_item(id, price):
	#var sender_id = multiplayer.get_remote_sender_id()
	for p in Alife_manager.player_array :
		if p.catnation_credits >= price:
			#print(p.name)
			#print(str(id))
			if p.name == str(id) :
				Alife_manager.get_node("Item_Manager").spawn_new_item(itemz_path,item_spawn_position)
				p.catnation_credits -= price
				change_quantity.rpc_id(id)

@rpc("any_peer","call_remote")
func change_quantity():
	quantity -= 1
	quantity_label.text = str("In stock: ") + str(quantity)
	
	
	

			
			
			
