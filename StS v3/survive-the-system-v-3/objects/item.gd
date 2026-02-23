extends Resource
class_name Item

@export var name: String
@export_enum("Tool", "Food","Biomass") var type:String
@export var inventory_icon : Texture2D
#@export var inventory_icon_path : String
@export var stack_amount:int
@export var item_path:String
