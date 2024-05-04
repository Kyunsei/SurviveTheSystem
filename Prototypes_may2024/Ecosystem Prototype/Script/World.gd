'''
This script contains global variable of the world
'''


extends Node


var Sun_energy = 100
#var Soil_food = 3000

#World Parameters
var instantiateRange = 35 
var BufferZoneSize = 0# (instantiateRange+2+2)*2 #wall+water
var worldsize = 100#temp
#var Map_size = Vector2(worldsize+BufferZoneSize,worldsize+BufferZoneSize)  # +50 is for stone wall and water


var Block_to_update = []
var Block_Matrix = []
var Block_Matrix_ElementState = []
var numberElement = 10
var visibleElementToggle = [1,1,0,0,0,0,0,0,0,0]
var createElementToggle = [1,0,0,0,0,0,0,0,0,0]
#definition of the 10 elements
var element_state = [0,0,0,0,1,1,1,2,2,2] # 0 solid, 1 liquide, 2 gas


var element_flow_in = [0.,0,0,0.,0,0,0,0,0,0] #speed at which element move from sphere to block.
var element_flow_out = [1.,.0,0.,0,0,0,0,0,0,0] #factor speed at which element move from block to sphere.

var element_flow_btw = [.7,.6,.5,0.5,.85,.0,.0,0,0,0] #factor 
var element_flow_btw_min = [0.5,0.5, 5.,2.0,.0,.0,.0,0,0,0] #min value in blocks to diffuse

var color_mapping = {
	0 : Color(0.3, 0.2, 0.1, 1), #soil
	1 : Color(0.3, 0.5, 0.3, 1), #vege
	2 : Color(0.8, 0.2, 0.5, 1), #meat
	3 : Color(0.125, 0.537, 0.561,1), #water
	4 : Color(1., 1., 1.,1), #gas1
	5 : Color(0.9, 0.5, 0.3,1), #gas2
	6 : Color(0., 0., 0.,1), 
	7 : Color(.0,.0,.0,1),
	8 : Color(.0,.0,.0,1),
	9 : Color(.0,.0,.0,1)
}


var Abioticsphere  = [0,0,0,0,500,0,0,0,0,0]
#fused intoOne
#var Atmosphere  = [100,100,100,100,100,100,100,100,100,100]
#var Hydroshpere = [0,5,5,5,5,5,5,5,5,5]
#var Lithosphere = [0,5,5,5,5,5,5,5,5,5]

var World_Speed = 1.

#10 min real time 
var Day_time = 8*60.
var Night_time = 2*60.

var Player_energy =  100.
var tile_size = 64#32#64 
var life_size_unit = 32
var day = 0


#debug
var grass_number=0
var berry_number=0
var meat_number = 0
var Total_Energy = 0
var Soil_Energy = 0
var Life_Energy = 0



	
'	
func ElementTransform():
	#This function descripe law for element transition
	#Not good, so not used
	var index = 0
	for e in World.element_state:
		if World.Lithosphere[index] > element_saturation[index]:
			if element_saturation_transition[index] != index:
				World.Lithosphere[element_saturation_transition[index]] += World.Lithosphere[index]/2
				World.Lithosphere[index] -= World.Lithosphere[index]/2
		if World.Atmosphere[index] > element_saturation[index]:
			if element_saturation_transition[index] != index:
				World.Atmosphere[element_saturation_transition[index]] += World.Atmosphere[index]/2
				World.Atmosphere[index] -= World.Atmosphere[index]/2
		if World.Hydroshpere[index] > element_saturation[index]:
			if element_saturation_transition[index] != index:
				World.Hydroshpere[element_saturation_transition[index]] += World.Hydroshpere[index]/2
				World.Hydroshpere[index] -= World.Hydroshpere[index]/2
		index +=1

	pass'
