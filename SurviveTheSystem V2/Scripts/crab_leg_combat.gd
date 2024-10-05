extends LifeEntity
var species = "crab_leg"
var isAttacking: bool = false


func Activate():
	set_collision_layer_value(1,1)
	$Crab_legArea2D/CollisionShape2D.disabled = true
	#$Crab_legArea2D/CollisionShape2D.shape.size = Vector2(34,72)

func Build_Genome():
	#set_collision_layer_value(1,1)
	Genome["maxPV"]=[200]
	Genome["soil_absorption"] = [0]
	Genome["lifespan"]=[100]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/crab_leg.png")]
	Genome["dead_sprite"] = [preload("res://Art/crab_leg_broken.png")]

# Called when the node enters the scene tree for the first time.
func _ready():
	$Crab_legArea2D/CollisionShape2D.disabled = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	


func Use_Attack():
	#size = Vector2(72,34)
	isAttacking = true
	$Crab_legArea2D/CollisionShape2D.disabled = false
	rotation = carried_by.last_dir.angle()
	#position = carried_by.position.normalized()*60
	$AnimationPlayer.play("Attack_animation")
	await $AnimationPlayer.animation_finished
	$Crab_legArea2D/CollisionShape2D.disabled = true
	isAttacking = false
		
	#
	#$BareHand_attack/sprite.show()
	#$BareHand_attack/ActionTimer.start(0.2)
	#for i in barehand_array:
		#if i != null:
			#i.getDamaged(10)
			
#var isAttacking: bool = false
#func Attack():
	#action_finished = false
	#if item_array.size() != 0:
		#if item_array[0].species == "crab_leg" :
			#$Object_attack.show()
			#$Object_attack/crab_leg_combat.show()
			#isAttacking = true
			#match(LastOrientation) :
				#"down":
					#$AnimationPlayer.play("Attack_animation")
				#"right":
					#$AnimationPlayer.play("Attack_animationUp")
				#"left":
					#$AnimationPlayer.play("Attack_animationLeft")
				#"up":
					#$AnimationPlayer.play("Attack_animationTrueUp")
			#await $AnimationPlayer.animation_finished
			#isAttacking = false
			#$Object_attack.hide()
			#$Object_attack/crab_leg_combat.hide()



#func _on_area_2d_area_entered(area):
	#if isAttacking == true:
				#print("something entered 2d colliion shape while attacking")
				#getClosestLife()
