extends Node2D
class_name LifeEntity


#OPTIMISATION CPU PERFORMANCE
var isActive = false
var pool_index = 0


#PHYSIC LAW
var lifecycletime = 30. #in second

#LifeRule
var isDead = false


#Genome parameters
var Genome = {
	"maxPV": [0],
	"sprite": [0]
}



#Inter parameters
var energy = 0  #current level of energy/hunger
var age = 0 #current age
var size = 0 #size from sprite
var PV = 0 #current level of health
var current_life_cycle = 0 #which state of life it is. egg, young, adult, etc..
var metabolic_cost = 1 #how much energy is consumed by cycle to keep biological function





