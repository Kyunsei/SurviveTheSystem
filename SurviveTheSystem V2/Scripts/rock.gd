extends StaticBody2D

#var energy = 0  #current level of energy/hunger
#var age = 0 #current age
var size = Vector2(32,32) #size from sprite
#var PV = 0 #current level of health
#var current_life_cycle = 0 #which state of life it is. egg, young, adult, etc..
#var metabolic_cost = 1 #how much energy is consumed by cycle to keep biological function
var species = "rock"
var carried_by = null

func getPickUP(transporter):
	if self.carried_by != null:
		carried_by.item_array.erase(self)
	self.carried_by = transporter
	transporter.item_array.append(self)
	$Collision_rock.disabled = true
	#seed.get_node("HitchHike_Timer").start(randf_range(1.5,4)/World.speed)

func getDropped(transporter) :
	if 	self.carried_by == transporter :
		carried_by.item_array.erase(self)
	carried_by = null
	$Collision_rock.disabled = false

func getDamaged(damagevalue) :
	pass
