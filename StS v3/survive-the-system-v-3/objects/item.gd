extends Resource
class_name ItemResource



@export var name: String
@export_enum("Tool", "Food","Biomass") var type:String
@export var inventory_icon : Texture2D
#@export var inventory_icon_path : String
@export var stack_amount:int
@export var item_path:String
#@export var durability:float
@export var Init_durability:float
@export var Name:String
@export var Max_quantity_in_shop:int
