extends ColorRect


# Called when the node enters the scene tree for the first time.
func _ready():
	$minium/value.text = str(World.diffusion_min_limit)
	$DiffusionSpeed/value.text = str(World.diffusion_speed)
	$DiffusionFactor/value.text = str(World.diffusion_factor)
	$DiffusionQuantity/value.text = str(World.diffusion_number)
	$Diffusionblocklimit/value.text = str(World.diffusion_block_limit)
	
	$minium.value = World.diffusion_min_limit
	$DiffusionSpeed.value = World.diffusion_speed
	$DiffusionFactor.value = World.diffusion_factor
	$DiffusionQuantity.value = World.diffusion_number
	$Diffusionblocklimit.value = World.diffusion_block_limit
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



#Diffusion Control

var diffusion_quantity_style = false # false = factor true = number
var diffusion_factor = 0.2
var diffusion_number = 1.

var diffusion_block_limit = 2 #how many block energy move. not implemented.



func _on_minium_value_changed(value):
	World.diffusion_min_limit = value
	$minium/value.text = str(value)
	pass # Replace with function body.


func _on_diffusion_speed_value_changed(value):
	World.diffusion_speed = value
	$DiffusionSpeed/value.text = str(value)
	get_parent().get_parent().UpdateSimulationSpeed()
	pass # Replace with function body.



func _on_diffusion_factor_value_changed(value):
	World.diffusion_factor = value
	$DiffusionFactor/value.text = str(value)


func _on_diffusion_quantity_value_changed(value):
	World.diffusion_number = value
	$DiffusionQuantity/value.text = str(value)



func _on_diffusionblocklimit_value_changed(value):
	World.diffusion_block_limit = value
	$Diffusionblocklimit/value.text = str(value)

