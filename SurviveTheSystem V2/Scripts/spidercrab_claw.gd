extends LifeEntity
var species = "spidercrab_claw"


var hastouchedsomething = false

func Build_Stat():
	self.current_life_cycle = 0
	self.PV = 500# Genome["maxPV"][self.current_life_cycle]	
	self.energy = 1
	self.maxPV = 500#Genome["maxPV"][self.current_life_cycle]	
	self.maxSpeed = 190
	self.lifespan = 200.
	self.size = get_node("Sprite_0").texture.get_size() * $Sprite_0.scale
	self.isPickable = true
	


# Called when the node enters the scene tree for the first time.
func _ready():
	Activate()


	
func _on_timer_timeout():
	if World.isReady and isActive:
		if isDead == false:
			
			#Absorb_soil_energy(0)
			#Metabo_cost()	
			#LifeDuplicate()
			Ageing()
			#Growth()
			if self.energy <= 0 or self.age >= self.lifespan  or self.PV <=0:
				Die()			
			if current_time_speed != World.speed:
				adapt_time_to_worldspeed()
		else:
			Deactivate()

func Use_Attack():
	if $Sprite_0.flip_h == false :
		$Sprite_0.flip_h = 1
	$Effect_Area/CollisionShape2D.disabled = false
	#rotation = carried_by.last_dir.angle()
	#position = carried_by.position.normalized()*60
	$AnimationPlayer.play("Attack_animation")
	await $AnimationPlayer.animation_finished
	$Effect_Area/CollisionShape2D.disabled = true

	if hastouchedsomething :
		hastouchedsomething = false
		self.PV -= 10
		if self.PV <= 0:
			Die()


func Activate():
	set_collision_layer_value(1,1)
	self.isActive = true
	self.isDead = false
	Build_Stat()
	show()
	
	$Effect_Area/CollisionShape2D.disabled = true
	Update_sprite($Sprite_0, $Collision_0)
	
	#set_physics_process(true)
	#Life.spidercrab_pool_state[self.pool_index] = 1

	$Timer.wait_time = lifecycletime / World.speed
	$Timer.start(randf_range(0,$Timer.wait_time))



func Deactivate():	
	#global_position = PickRandomPlaceWithRange(position,5 * World.tile_size)
	#set_physics_process(false)
	Decomposition(0)
	set_collision_layer_value(1,false)
	#$Vision.set_collision_mask_value(1,false)
	$Timer.stop()
	self.isActive = false

	#hide()
	queue_free()


func Die():
	self.isDead = true
	velocity = Vector2(0,0)
	if carried_by != null:
		carried_by.item_array.erase(self)
		carried_by = null
		z_index = 0
	Update_sprite($Dead_Sprite_0)
	#$Crab_clawArea2D/CollisionShape2D.queue_free()



func _on_effect_area_body_entered(body):
	if carried_by:
		if body.species != "block" and body != carried_by and body != self:
			body.getDamaged(50,carried_by)
			hastouchedsomething = true
