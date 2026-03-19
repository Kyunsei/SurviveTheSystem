extends Button


var item_resource: ItemResource
var quantity: int

var image
var quantity_label 

func _ready():
	pass
func setup(item: ItemResource, qty: int):
	image = $TextureRect
	quantity_label = $Quantity 
	#$TextureRect.texture =textur
	item_resource = item
	quantity = qty
	#if item.inventory_icon:
	image.texture = item.inventory_icon
	if quantity:
		quantity_label.text = str(quantity)
