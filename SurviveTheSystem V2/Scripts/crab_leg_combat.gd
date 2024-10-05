extends LifeEntity
var species = "crab_leg"

func Activate():
	set_collision_layer_value(1,1)

	

func Build_Genome():
	#set_collision_layer_value(1,1)
	Genome["maxPV"]=[200]
	Genome["soil_absorption"] = [0]
	Genome["lifespan"]=[100]#randi_range(15,20)]
	Genome["sprite"] = [preload("res://Art/crab_leg.png")]
	Genome["dead_sprite"] = [preload("res://Art/crab_leg_broken.png")]

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	
func Use_Attack():
	pass
	#size = Vector2(72,34)
	#rotation = carried_by.last_dir.angle()
	#position = carried_by.position + Vector2(16,32)*carried_by.last_dir
	#position = carried_by.position +  carried_by.last_dir * $CollisionShape2D.shape.size* Vector2(0.5,0.5)  - Vector2(64,64) * Vector2(-0.25,0)
#	$AnimationPlayer.play("Attack_animation")
#	await $AnimationPlayer.animation_finished
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
